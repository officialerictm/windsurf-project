import React from 'react';
import { Paper, Box, Typography, Avatar, Stack } from '@mui/material';

const buddies = [
  {
    name: 'Ollie the Owl',
    emoji: '🦉',
    description: 'Your wise simulation announcer! Ollie gives live commentary and fun facts about the world.'
  }
  // Add more buddies here in the future!
];

export default function BuddiesLegend() {
  return (
    <Paper elevation={4} sx={{ position: 'fixed', bottom: 24, right: 24, p: 2, borderRadius: 3, zIndex: 1000, minWidth: 220, bgcolor: '#f0f4ff', maxWidth: 280 }}>
      <Typography variant="subtitle1" sx={{ mb: 1, fontWeight: 'bold' }}>Meet Your Buddies</Typography>
      <Stack spacing={1}>
        {buddies.map((b, i) => (
          <Box key={b.name} sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <Avatar sx={{ bgcolor: '#fffbe7', width: 36, height: 36, fontSize: 28 }}>{b.emoji}</Avatar>
            <Box>
              <Typography variant="body1" sx={{ fontWeight: 500 }}>{b.name}</Typography>
              <Typography variant="body2" sx={{ color: 'text.secondary' }}>{b.description}</Typography>
            </Box>
          </Box>
        ))}
      </Stack>
    </Paper>
  );
}
