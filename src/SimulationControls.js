import React from 'react';
import {
  Box,
  Typography,
  Slider,
  Button,
  TextField,
  Stack,
  IconButton,
  Tooltip,
} from '@mui/material';
import { PlayArrow, Pause, Settings, Info } from '@mui/icons-material';

const SimulationControls = ({
  gridSize,
  foodSpawnRate,
  simulationSpeed,
  isRunning,
  setIsRunning,
  setGridSize,
  setFoodSpawnRate,
  setSimulationSpeed,
}) => {
  return (
    <Box>
      <Typography variant="h6" gutterBottom>
        Simulation Controls
      </Typography>
      
      <Stack spacing={2}>
        <Box>
          <Typography variant="subtitle2" gutterBottom>
            Grid Size:
          </Typography>
          <Slider
            value={gridSize}
            onChange={(_, value) => setGridSize(value)}
            min={10}
            max={50}
            step={1}
            marks
            valueLabelDisplay="auto"
          />
        </Box>

        <Box>
          <Typography variant="subtitle2" gutterBottom>
            Food Spawn Rate:
          </Typography>
          <Slider
            value={foodSpawnRate}
            onChange={(_, value) => setFoodSpawnRate(value)}
            min={10}
            max={100}
            step={1}
            marks
            valueLabelDisplay="auto"
          />
        </Box>

        <Box>
          <Typography variant="subtitle2" gutterBottom>
            Simulation Speed:
          </Typography>
          <Slider
            value={simulationSpeed}
            onChange={(_, value) => setSimulationSpeed(value)}
            min={1}
            max={60}
            step={1}
            marks
            valueLabelDisplay="auto"
          />
        </Box>

        <Button
          variant="contained"
          color="primary"
          onClick={() => setIsRunning(!isRunning)}
          startIcon={isRunning ? <Pause /> : <PlayArrow />}
          fullWidth
        >
          {isRunning ? 'Pause' : 'Start'}
        </Button>

        <Stack direction="row" spacing={1} justifyContent="space-between">
          <Tooltip title="Settings">
            <IconButton color="primary">
              <Settings />
            </IconButton>
          </Tooltip>
          <Tooltip title="Info">
            <IconButton color="primary">
              <Info />
            </IconButton>
          </Tooltip>
        </Stack>
      </Stack>
    </Box>
  );
};

export default SimulationControls;
