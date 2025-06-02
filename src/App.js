import React, { useState, useEffect, useCallback } from 'react';
import {
  Box,
  Container,
  Typography,
  Grid,
  Paper,
  Tabs,
  Tab,
  Stack,
  IconButton,
  Tooltip,
} from '@mui/material';
import {
  GitHub,
  Share,
} from '@mui/icons-material';
import * as THREE from 'three'; // Import THREE for Color conversion
import GridCanvas from './GridCanvas';
import SimulationControls from './SimulationControls';
import EvolutionControls from './EvolutionControls';
import Statistics from './Statistics';
import GlobeView from './GlobeView';

const CELL_TYPES = {
  FOOD: 'food',
  ORGANISM: 'organism',
  EMPTY: 'empty',
  PREDATOR: 'predator',
};

const TERRAIN_TYPES = {
  LAND: 'land',
  WATER: 'water',
};

const METABOLIC_COST = 1; // Energy consumed each step just to live
const ENERGY_FROM_FOOD = 10; // Energy gained from eating food

const INITIAL_ORGANISMS = 10;

function App() {
  const [activeTab, setActiveTab] = useState('simulation');
  const [gridSize, setGridSize] = useState(30);
  const [foodSpawnRate, setFoodSpawnRate] = useState(60);
  const [minCellSize, setMinCellSize] = useState(600 / 30);

  const randomPos = (size = gridSize) => [
    Math.floor(Math.random() * size),
    Math.floor(Math.random() * size),
  ];

  const [grid, setGrid] = useState(() => {
    const g = Array(gridSize).fill(null).map(() => Array(gridSize).fill(CELL_TYPES.EMPTY));
    for (let i = 0; i < foodSpawnRate; i++) {
      const [x, y] = randomPos(gridSize);
      g[x][y] = CELL_TYPES.FOOD;
    }
    return g;
  });

  const [terrainGrid, setTerrainGrid] = useState(() => {
    const tg = Array(gridSize).fill(null).map(() => Array(gridSize).fill(null));
    const terrainBlockSize = 5; // Each block of 5x5 cells will have the same terrain type
    const numBlocks = Math.ceil(gridSize / terrainBlockSize);

    // Create a temporary grid for block-level terrain decisions
    const blockTerrain = Array(numBlocks).fill(null).map(() => Array(numBlocks).fill(null));
    for (let rBlock = 0; rBlock < numBlocks; rBlock++) {
      for (let cBlock = 0; cBlock < numBlocks; cBlock++) {
        blockTerrain[rBlock][cBlock] = Math.random() < 0.7 ? TERRAIN_TYPES.WATER : TERRAIN_TYPES.LAND;
      }
    }

    // Assign terrain to cells based on their block
    for (let r = 0; r < gridSize; r++) {
      for (let c = 0; c < gridSize; c++) {
        const rBlock = Math.floor(r / terrainBlockSize);
        const cBlock = Math.floor(c / terrainBlockSize);
        tg[r][c] = blockTerrain[rBlock][cBlock];
      }
    }
    return tg;
  });

  const [organisms, setOrganisms] = useState(() => {
    const arr = Array(INITIAL_ORGANISMS).fill(null).map(() => {
      let x, y;
      const habitat = TERRAIN_TYPES.LAND; // All initial organisms are land dwellers
      let foundSpot = false;
      let attempts = 0;
      // Try to find a valid spawn spot for the organism's habitat
      while (!foundSpot && attempts < gridSize * gridSize) { // Limit attempts to prevent infinite loop
        const [randX, randY] = randomPos(gridSize);
        if (terrainGrid[randX][randY] === habitat) {
          x = randX;
          y = randY;
          foundSpot = true;
        }
        attempts++;
      }
      // If no spot found after many attempts (e.g., no land cells), place randomly as fallback
      if (!foundSpot) {
        [x, y] = randomPos(gridSize);
        // console.warn(`Could not find ${habitat} spot for organism, placing randomly.`);
      }

      return {
        id: Date.now() + Math.random(),
        x, y,
        habitat, // Store habitat
        energy: 20,
        traits: {
          speed: 1,
          vision: 2,
          colorHue: Math.floor(Math.random() * 360),
          size: 1,
          pattern: 0
        }
      };
    });
    return arr.filter(org => org.x !== undefined && org.y !== undefined); // Filter out any unplaced orgs
  });

  const [simulationSpeed, setSimulationSpeed] = useState(2);
  const [isRunning, setIsRunning] = useState(false);
  const [stats, setStats] = useState({
    totalPopulation: INITIAL_ORGANISMS,
    foodCount: foodSpawnRate,
    speciesCount: 1
  });
  const [tick, setTick] = useState(0);

  // Derive globe markers from organisms state
  const globeMarkers = organisms.map(org => {
    const lon = (org.x / (gridSize > 1 ? gridSize - 1 : 1)) * 360 - 180;
    const lat = 90 - (org.y / (gridSize > 1 ? gridSize - 1 : 1)) * 180;
    const color = new THREE.Color().setHSL(org.traits.colorHue / 360, 1.0, 0.5).getHex();
    const size = Math.max(0.05, (org.traits.size || 1) * 0.1);

    return {
      id: `org-${org.id}`,
      lat,
      lon,
      color,
      size,
    };
  });

  // Add food markers from the grid state
  for (let r = 0; r < gridSize; r++) {
    for (let c = 0; c < gridSize; c++) {
      if (grid[r][c] === CELL_TYPES.FOOD) {
        const lon = (c / (gridSize > 1 ? gridSize - 1 : 1)) * 360 - 180;
        const lat = 90 - (r / (gridSize > 1 ? gridSize - 1 : 1)) * 180;
        globeMarkers.push({
          id: `food-${r}-${c}`,
          lat,
          lon,
          color: 0x90EE90,
          size: 0.08,
        });
      }
    }
  }

  // --- Simulation Logic --- 

  const advanceSimulation = useCallback(() => {
    // --- Part 1: Update Organisms & Identify Eaten Food --- 
    let eatenFoodCoords = []; // Store [x, y] of eaten food cells
    const livingOrganismsNext = organisms
      .map(org => {
        // 1. Apply Metabolic Cost
        let currentEnergy = org.energy - METABOLIC_COST;
        if (currentEnergy <= 0) return null; // Died from metabolism

        // 2. Check for Food at STARTING position & Consume
        let ateFood = false;
        if (grid[org.x][org.y] === CELL_TYPES.FOOD) {
          currentEnergy += ENERGY_FROM_FOOD;
          eatenFoodCoords.push([org.x, org.y]); // Record location of eaten food
          ateFood = true; 
        }

        // 3. Find Target Food (only for movement direction)
        let minDist = Infinity;
        let targetFoodPos = null;
        // (Using grid state for food positions - assumes grid state is accurate enough for direction finding)
        for (let i = 0; i < gridSize; i++) {
            for (let j = 0; j < gridSize; j++) {
                if (grid[i][j] === CELL_TYPES.FOOD && terrainGrid[i][j] === org.habitat) {
                   const dist = Math.sqrt((i - org.x) ** 2 + (j - org.y) ** 2);
                   if (dist < minDist) {
                     minDist = dist;
                     targetFoodPos = [i, j];
                   }
                }
            }
        }
        
        let fx = org.x, fy = org.y; 
        if (targetFoodPos) {
          fx = targetFoodPos[0];
          fy = targetFoodPos[1];
        }

        // 4. Calculate Movement
        const dx = Math.sign(fx - org.x);
        const dy = Math.sign(fy - org.y);
        const newX = (org.x + dx + gridSize) % gridSize;
        const newY = (org.y + dy + gridSize) % gridSize;
        const targetKey = `${newX},${newY}`;

        // Check if target cell is valid (correct terrain and not occupied *by another organism ending its move there*)
        // Simple check for now: is target terrain valid? We'll handle collisions implicitly later.
        let finalX = org.x;
        let finalY = org.y;
        if (dx !== 0 || dy !== 0) { // Only check if attempting to move
           if (terrainGrid[newX][newY] === org.habitat) {
              // Basic check: move if terrain is ok. More complex collision needed later.
              finalX = newX;
              finalY = newY;
           }
        } 
        
        // Return updated organism state
        return {
          ...org,
          x: finalX,
          y: finalY,
          energy: currentEnergy
        };
      })
      .filter(org => org !== null); // Remove nulls (died from metabolism)

    // Update organism state
    setOrganisms(livingOrganismsNext);

    // --- Part 2: Update Grid based on new organism state and eaten food --- 
    const eatenFoodSet = new Set(eatenFoodCoords.map(coords => `${coords[0]},${coords[1]}`));
    setGrid(prevGrid => {
        // 1. Initialize new grid (empty)
        let newGrid = Array(gridSize).fill(null).map(() => Array(gridSize).fill(CELL_TYPES.EMPTY));
        
        // 2. Place Organisms (handle potential collisions - simple overwrite for now)
        const occupiedByOrganism = new Set();
        livingOrganismsNext.forEach(org => {
            newGrid[org.x][org.y] = CELL_TYPES.ORGANISM;
            occupiedByOrganism.add(`${org.x},${org.y}`);
        });

        // 3. Place remaining food (from previous grid, filtering out eaten food and spots now occupied by organisms)
        let currentFoodCount = 0;
        for (let r = 0; r < gridSize; r++) {
            for (let c = 0; c < gridSize; c++) {
                const key = `${r},${c}`;
                if ( prevGrid[r][c] === CELL_TYPES.FOOD && 
                     !eatenFoodSet.has(key) && 
                     !occupiedByOrganism.has(key) ) 
                {
                    newGrid[r][c] = CELL_TYPES.FOOD;
                    currentFoodCount++;
                }
            }
        }

        // 4. Spawn new food
        let tries = 0;
        while (currentFoodCount < foodSpawnRate && tries < 100) {
            const [fx, fy] = randomPos(gridSize);
            if (newGrid[fx][fy] === CELL_TYPES.EMPTY && terrainGrid[fx][fy] === TERRAIN_TYPES.LAND) { // Only spawn food on land for now
              newGrid[fx][fy] = CELL_TYPES.FOOD;
              currentFoodCount++;
            }
            tries++;
        }
        return newGrid;
    });

    // --- Part 3: Update Stats --- (Should use the results from Part 1)
    const totalEnergy = livingOrganismsNext.reduce((sum, org) => sum + org.energy, 0);
    setStats(prevStats => ({
        ...prevStats,
        step: prevStats.step + 1,
        organismCount: livingOrganismsNext.length,
        totalEnergy: Math.round(totalEnergy)
    }));

  }, [organisms, grid, gridSize, foodSpawnRate, terrainGrid, METABOLIC_COST, ENERGY_FROM_FOOD]); // Added dependencies

  // --- Simulation Runner --- 
  useEffect(() => {
    if (!isRunning) return;
    const interval = setInterval(() => {
      advanceSimulation();
    }, 1000 / simulationSpeed);
    return () => clearInterval(interval);
  }, [isRunning, simulationSpeed, advanceSimulation]); // <-- Corrected dependencies

  useEffect(() => {
    if (!isRunning) return;
    const interval = setInterval(() => {
      advanceSimulation();
    }, 1000 / simulationSpeed);
    return () => clearInterval(interval);
  }, [isRunning, simulationSpeed, advanceSimulation]);

  return (
    <Box sx={{ flexGrow: 1, p: 2 }}>
      <Container maxWidth="lg">
        <>
          <Box>
            <Typography variant="h3" component="h1" gutterBottom>
              The Life Engine
            </Typography>
            <Tabs
              value={activeTab}
              onChange={(e, newValue) => setActiveTab(newValue)}
              variant="fullWidth"
              centered
            >
              <Tab value="simulation" label="Simulation" />
              <Tab value="globe" label="3D Globe" />
              <Tab value="evolution" label="Evolution" />
              <Tab value="statistics" label="Statistics" />
            </Tabs>
            <Box sx={{ mt: 3 }}>
              {activeTab === 'simulation' && (
                <Grid container spacing={3}>
                  <Grid item xs={12} md={8}>
                    <Paper sx={{ p: 2, height: '100%' }}>
                      <GridCanvas
                        gridSize={gridSize}
                        minCellSize={minCellSize}
                        grid={grid}
                        organisms={organisms}
                        isRunning={isRunning}
                        setGrid={setGrid}
                        setOrganisms={setOrganisms}
                        setStats={setStats}
                        terrainGrid={terrainGrid}
                      />
                    </Paper>
                  </Grid>
                  <Grid item xs={12} md={4}>
                    <Paper sx={{ p: 2, height: '100%', display: 'flex', flexDirection: 'column' }}>
                      <Stack spacing={2} sx={{ flexGrow: 1 }}>
                        <SimulationControls
                          gridSize={gridSize}
                          foodSpawnRate={foodSpawnRate}
                          simulationSpeed={simulationSpeed}
                          isRunning={isRunning}
                          setIsRunning={setIsRunning}
                          setGridSize={setGridSize}
                          setFoodSpawnRate={setFoodSpawnRate}
                          setSimulationSpeed={setSimulationSpeed}
                        />
                      </Stack>
                      <Stack direction="row" spacing={1} sx={{ mt: 'auto' }}>
                        <Tooltip title="GitHub Repository">
                          <IconButton color="primary">
                            <GitHub />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Share">
                          <IconButton color="primary">
                            <Share />
                          </IconButton>
                        </Tooltip>
                      </Stack>
                    </Paper>
                  </Grid>
                </Grid>
              )}
              {activeTab === 'globe' && (
                <GlobeView 
                  organisms={organisms} 
                  gridSize={gridSize} 
                />
              )}
              {activeTab === 'evolution' && <EvolutionControls />}
              {activeTab === 'statistics' && <Statistics stats={stats} />}
            </Box>
          </Box>
        </>
      </Container>
    </Box>
  );
}

export default App;
