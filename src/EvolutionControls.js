import React from 'react';
import {
  Box,
  Typography,
  Slider,
  TextField,
  Button,
  Stack,
  Paper,
  Grid,
} from '@mui/material';

const EvolutionControls = () => {
  return (
    <Box>
      <Typography variant="h6" gutterBottom>
        Evolution Controls
      </Typography>
      
      <Paper sx={{ p: 2, mb: 2 }}>
        <Typography variant="subtitle1" gutterBottom>
          Mutation Rates
        </Typography>
        <Grid container spacing={2}>
          <Grid item xs={12}>
            <Typography variant="subtitle2" gutterBottom>
              Speed Mutation Rate:
            </Typography>
            <Slider
              value={0.1}
              onChange={(_, value) => console.log(value)}
              min={0}
              max={1}
              step={0.01}
              marks
              valueLabelDisplay="auto"
            />
          </Grid>
          <Grid item xs={12}>
            <Typography variant="subtitle2" gutterBottom>
              Vision Mutation Rate:
            </Typography>
            <Slider
              value={0.1}
              onChange={(_, value) => console.log(value)}
              min={0}
              max={1}
              step={0.01}
              marks
              valueLabelDisplay="auto"
            />
          </Grid>
          <Grid item xs={12}>
            <Typography variant="subtitle2" gutterBottom>
              Size Mutation Rate:
            </Typography>
            <Slider
              value={0.1}
              onChange={(_, value) => console.log(value)}
              min={0}
              max={1}
              step={0.01}
              marks
              valueLabelDisplay="auto"
            />
          </Grid>
        </Grid>
      </Paper>

      <Paper sx={{ p: 2, mb: 2 }}>
        <Typography variant="subtitle1" gutterBottom>
          Behavior Settings
        </Typography>
        <Grid container spacing={2}>
          <Grid item xs={12}>
            <Typography variant="subtitle2" gutterBottom>
              Food Attraction:
            </Typography>
            <Slider
              value={0.8}
              onChange={(_, value) => console.log(value)}
              min={0}
              max={1}
              step={0.01}
              marks
              valueLabelDisplay="auto"
            />
          </Grid>
          <Grid item xs={12}>
            <Typography variant="subtitle2" gutterBottom>
              Predator Avoidance:
            </Typography>
            <Slider
              value={0.9}
              onChange={(_, value) => console.log(value)}
              min={0}
              max={1}
              step={0.01}
              marks
              valueLabelDisplay="auto"
            />
          </Grid>
        </Grid>
      </Paper>

      <Button
        variant="contained"
        color="primary"
        fullWidth
      >
        Apply Changes
      </Button>
    </Box>
  );
};

export default EvolutionControls;
