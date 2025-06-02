import React, { useRef, useEffect, useState } from 'react';

/**
 * GridCanvas renders the simulation grid and organisms using HTML Canvas.
 * Supports zooming and panning with mouse and keyboard.
 *
 * Props:
 *   grid: 2D array of cell types
 *   organisms: array of organism objects
 *   gridSize: number (width/height of grid)
 *   cellSize: base size of a cell (optional, default 20)
 *   terrainGrid: 2D array of terrain types ('land' or 'water')
 */
export default function GridCanvas({ grid, organisms, gridSize, cellSize = 20, terrainGrid }) {
  const canvasRef = useRef(null);
  const [zoom, setZoom] = useState(1);
  const [offset, setOffset] = useState({ x: 0, y: 0 });

  // Auto-center and fit grid to canvas on mount or gridSize change
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    // Fit grid with margin (10% of canvas size)
    const margin = 40;
    const gridPixelSize = gridSize * cellSize;
    const zoomX = (canvas.width - 2 * margin) / gridPixelSize;
    const zoomY = (canvas.height - 2 * margin) / gridPixelSize;
    const fitZoom = Math.min(zoomX, zoomY, 1.5); // don't zoom in too much
    setZoom(fitZoom);
    setOffset({
      x: (canvas.width - gridPixelSize * fitZoom) / 2,
      y: (canvas.height - gridPixelSize * fitZoom) / 2
    });
    // eslint-disable-next-line
  }, [gridSize, cellSize]);
  const [dragging, setDragging] = useState(false);
  const [lastMouse, setLastMouse] = useState(null);

  // Define terrain colors
  const WATER_COLOR = '#ADD8E6'; // Light blue for water
  const LAND_COLOR = '#D2B48C';  // Light tan for land
  const DEFAULT_CELL_COLOR = '#f0f0f0'; // Fallback for unknown terrain or if terrainGrid is missing

  // Handle zoom with mouse wheel and ctrl+up/down
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const handleWheel = (e) => {
      e.preventDefault();
      let newZoom = zoom * (e.deltaY < 0 ? 1.1 : 0.9);
      newZoom = Math.max(0.1, Math.min(5, newZoom));
      setZoom(newZoom);
    };
    canvas.addEventListener('wheel', handleWheel, { passive: false });
    return () => canvas.removeEventListener('wheel', handleWheel);
  }, [zoom]);

  // Keyboard zoom (ctrl+up/down)
  useEffect(() => {
    const handleKey = (e) => {
      if (e.ctrlKey && (e.key === 'ArrowUp' || e.key === 'ArrowDown')) {
        setZoom(z => {
          let newZoom = z * (e.key === 'ArrowUp' ? 1.1 : 0.9);
          return Math.max(0.1, Math.min(5, newZoom));
        });
      }
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, []);

  // Mouse drag for panning
  const handleMouseDown = (e) => {
    setDragging(true);
    setLastMouse({ x: e.clientX, y: e.clientY });
  };
  const handleMouseUp = () => setDragging(false);
  const handleMouseMove = (e) => {
    if (!dragging || !lastMouse) return;
    const dx = e.clientX - lastMouse.x;
    const dy = e.clientY - lastMouse.y;
    setOffset(off => ({ x: off.x + dx, y: off.y + dy }));
    setLastMouse({ x: e.clientX, y: e.clientY });
  };

  // Draw grid and organisms
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const width = canvas.width;
    const height = canvas.height;
    ctx.clearRect(0, 0, width, height);
    ctx.save();
    ctx.translate(offset.x, offset.y);
    ctx.scale(zoom, zoom);
    // Draw grid cells
    for (let i = 0; i < gridSize; i++) {
      for (let j = 0; j < gridSize; j++) {
        const x = i * cellSize;
        const y = j * cellSize;
        // Only draw if visible
        if (
          x * zoom + offset.x > -cellSize &&
          y * zoom + offset.y > -cellSize &&
          x * zoom + offset.x < width &&
          y * zoom + offset.y < height
        ) {
          // 1. Draw terrain background
          let terrainColor = DEFAULT_CELL_COLOR;
          if (terrainGrid && terrainGrid[i] && terrainGrid[i][j]) {
            if (terrainGrid[i][j] === 'water') {
              terrainColor = WATER_COLOR;
            } else if (terrainGrid[i][j] === 'land') {
              terrainColor = LAND_COLOR;
            }
          }
          ctx.fillStyle = terrainColor;
          ctx.fillRect(x, y, cellSize, cellSize);

          // 2. Draw food on top of terrain
          if (grid[i][j] === 'food') {
            ctx.fillStyle = '#4caf50'; // Green for food
            // To make food more distinct, maybe draw a smaller rect or circle?
            // For now, full cell fill like before, but on top of terrain.
            ctx.fillRect(x, y, cellSize, cellSize);
          }
          // Note: The 'organism' case for grid[i][j] is removed as organisms are drawn from the organisms array.
          
          // 3. Draw grid lines
          ctx.strokeStyle = '#ccc';
          ctx.strokeRect(x, y, cellSize, cellSize);
        }
      }
    }
    // Draw organisms
    organisms.forEach((org) => {
      const { x, y, traits } = org;
      // Clamp organism position to grid
      const cx = Math.max(0, Math.min(gridSize - 1, x)) * cellSize + cellSize / 2;
      const cy = Math.max(0, Math.min(gridSize - 1, y)) * cellSize + cellSize / 2;
      // Organism radius: max 40% of cell size, never exceeds cell
      const radius = Math.min(cellSize * 0.4, cellSize / 2 - 2);
      ctx.save();
      ctx.beginPath();
      ctx.arc(cx, cy, radius, 0, 2 * Math.PI);
      ctx.fillStyle = `hsl(${traits?.colorHue ?? 180}, 70%, 55%)`;
      ctx.globalAlpha = 0.95;
      ctx.fill();
      ctx.globalAlpha = 1.0;
      ctx.restore();
    });
    ctx.restore();
  }, [grid, organisms, gridSize, cellSize, zoom, offset, terrainGrid]); // Added terrainGrid to dependencies

  return (
    <canvas
      ref={canvasRef}
      width={800}
      height={800}
      tabIndex={0}
      style={{
        border: '2px solid #bbb',
        background: '#fafaff',
        outline: 'none',
        cursor: dragging ? 'grabbing' : 'grab',
        width: '100%',
        height: '100%',
        display: 'block',
      }}
      onMouseDown={handleMouseDown}
      onMouseUp={handleMouseUp}
      onMouseLeave={handleMouseUp}
      onMouseMove={handleMouseMove}
    />
  );
}
