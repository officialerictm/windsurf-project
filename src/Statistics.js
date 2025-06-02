import React from 'react';
import {
  Box,
  Typography,
  Grid,
  Card,
  CardContent,
  CardHeader,
  LinearProgress,
  Stack,
  Avatar,
} from '@mui/material';
import { TrendingUp, TrendingDown } from '@mui/icons-material';

const Statistics = ({ stats }) => {
  return (
    <Box>
      <Typography variant="h6" gutterBottom>
        Statistics
      </Typography>
      
      <Grid container spacing={2}>
        <Grid item xs={12} sm={6}>
          <Card>
            <CardHeader
              avatar={
                <Avatar sx={{ bgcolor: '#2196f3' }}>
                  🌱
                </Avatar>
              }
              title="Organisms"
              subheader={`Total: ${stats.totalPopulation || 0}`}
            />
            <CardContent>
              <Typography variant="body2" color="text.secondary">
                Current Population
              </Typography>
              <LinearProgress
                variant="determinate"
                value={Math.min(100, (stats.totalPopulation || 0) * 2)}
                sx={{ mt: 1 }}
              />
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6}>
          <Card>
            <CardHeader
              avatar={
                <Avatar sx={{ bgcolor: '#4caf50' }}>
                  🍎
                </Avatar>
              }
              title="Food"
              subheader={`Available: ${stats.foodCount || 0}`}
            />
            <CardContent>
              <Typography variant="body2" color="text.secondary">
                Food Abundance
              </Typography>
              <LinearProgress
                variant="determinate"
                value={Math.min(100, (stats.foodCount || 0) / 100 * 100)}
                sx={{ mt: 1 }}
              />
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      <Card sx={{ mt: 2 }}>
        <CardHeader title="Evolutionary Trends" />
        <CardContent>
          <Stack spacing={2}>
            <Box>
              <Typography variant="subtitle2" gutterBottom>
                Most Successful Traits
              </Typography>
              <Stack direction="row" spacing={2}>
                <Box>
                  <TrendingUp color="success" />
                  <Typography variant="body2">Speed: 1.5x</Typography>
                </Box>
                <Box>
                  <TrendingUp color="success" />
                  <Typography variant="body2">Vision: 1.2x</Typography>
                </Box>
              </Stack>
            </Box>

            <Box>
              <Typography variant="subtitle2" gutterBottom>
                Species Diversity
              </Typography>
              <Typography variant="body2">
                Current Species: {stats.speciesCount || 0}
              </Typography>
            </Box>
          </Stack>
        </CardContent>
      </Card>
    </Box>
  );
};

export default Statistics;
