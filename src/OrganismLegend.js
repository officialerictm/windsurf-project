import React, { useState, useEffect } from 'react';
import { Paper, Box, Typography, Stack, Avatar } from '@mui/material';
import { keyframes } from '@emotion/react';

export default function OrganismLegend({ organisms }) {
  // ColorHue to cute name and description mapping, with rotating descriptions and fun facts
  const colorNames = [
    {
      name: 'Ruby Roamer',
      color: '#e74c3c',
      descs: [
        'Bold and adventurous!',
        'Never afraid of a challenge.',
        'Leads the charge into new territory.'
      ],
      funFact: 'Ruby Roamers are known for their fiery tempers!'
    },
    {
      name: 'Sunny Blob',
      color: '#f1c40f',
      descs: [
        'Brings sunshine wherever it goes.',
        'Always the optimist!',
        'Spreads cheer on the grid.'
      ],
      funFact: 'Sunny Blobs love to gather in groups for warmth.'
    },
    {
      name: 'Minty Muncher',
      color: '#2ecc71',
      descs: [
        'Loves to snack on food.',
        'Always munching!',
        'Rarely seen without a bite to eat.'
      ],
      funFact: 'Minty Munchers can detect food from far away.'
    },
    {
      name: 'Azure Explorer',
      color: '#3498db',
      descs: [
        'Always on the move.',
        'Seeks out new adventures.',
        'Never stays in one place for long.'
      ],
      funFact: 'Azure Explorers have mapped more of the grid than any other.'
    },
    {
      name: 'Violet Dreamer',
      color: '#9b59b6',
      descs: [
        'Quiet, but full of surprises.',
        'Often lost in thought.',
        'Dreams of a better world.'
      ],
      funFact: 'Violet Dreamers sometimes move in their sleep!'
    },
    {
      name: 'Pumpkin Prowler',
      color: '#e67e22',
      descs: [
        'Sneaky and quick!',
        'Loves a good chase.',
        'Masters of disguise.'
      ],
      funFact: 'Pumpkin Prowlers are rarely caught by predators.'
    },
    {
      name: 'Rose Wanderer',
      color: '#e84393',
      descs: [
        'Gentle and curious.',
        'Wanders with purpose.',
        'Finds beauty everywhere.'
      ],
      funFact: 'Rose Wanderers are the best at making friends.'
    },
    {
      name: 'Lime Sprinter',
      color: '#00b894',
      descs: [
        'Fastest on the grid!',
        'Leaves others in the dust.',
        'Always in a hurry.'
      ],
      funFact: 'Lime Sprinters can cross the grid in record time.'
    },
    {
      name: 'Sky Hopper',
      color: '#00cec9',
      descs: [
        'Jumps from spot to spot.',
        'Never walks when they can hop.',
        'Loves heights!'
      ],
      funFact: 'Sky Hoppers can leap over obstacles with ease.'
    },
    {
      name: 'Sandstone Shuffler',
      color: '#fdcb6e',
      descs: [
        'Blends in with the crowd.',
        'Moves with a steady rhythm.',
        'Always calm and collected.'
      ],
      funFact: 'Sandstone Shufflers are masters of camouflage.'
    },
  ];

  function getColorGroup(hue) {
    // Map hue (0-359) to nearest colorNames index
    const idx = Math.round((hue % 360) / 36) % colorNames.length;
    return { ...colorNames[idx], idx };
  }

  // Helper to pick rotating description for a group
  function getRotatingDesc(descs, tick) {
    return descs[tick % descs.length];
  }

  // Animation: gentle bounce
  const bounce = keyframes`
    0%, 100% { transform: translateY(0); }
    50% { transform: translateY(-6px); }
  `;

  // Group organisms by colorHue (rounded)
  const groups = {};
  let energySums = {};
  organisms.forEach(o => {
    const hue = Math.round(o.traits?.colorHue ?? 0);
    const group = getColorGroup(hue);
    if (!groups[group.name]) {
      groups[group.name] = { ...group, count: 0, sumEnergy: 0 };
    }
    groups[group.name].count++;
    groups[group.name].sumEnergy += o.energy ?? 0;
  });

  // Sort groups by count, take top 5
  const sortedGroups = Object.values(groups).sort((a, b) => b.count - a.count).slice(0, 5);

  // Find buddy of the day (most numerous)
  const buddyOfDay = sortedGroups[0];

  // Use tick for rotating descs
  const [tick, setTick] = useState(0);
  useEffect(() => {
    const t = setInterval(() => setTick(tick => tick + 1), 3500);
    return () => clearInterval(t);
  }, []);

  return (
    <Paper elevation={4} sx={{ position: 'fixed', bottom: 24, right: 24, p: 2, borderRadius: 3, zIndex: 1000, minWidth: 240, bgcolor: '#f9f9fc', maxWidth: 320 }}>
      <Typography variant="subtitle1" sx={{ mb: 1, fontWeight: 'bold' }}>Meet Your Buddies</Typography>
      <Stack spacing={1}>
        {sortedGroups.map((g, i) => {
          const avgEnergy = g.count ? Math.round(g.sumEnergy / g.count) : 0;
          const isBuddyOfDay = g.name === buddyOfDay.name;
          return (
            <Box key={g.name} sx={{ display: 'flex', alignItems: 'center', gap: 1, position: 'relative' }}>
              <Avatar
                sx={{
                  bgcolor: g.color,
                  width: 36,
                  height: 36,
                  fontSize: 28,
                  animation: `${bounce} 2.1s ease-in-out infinite`,
                  border: isBuddyOfDay ? '3px solid #ffd700' : undefined,
                  boxShadow: isBuddyOfDay ? '0 0 8px 2px #ffe066' : undefined,
                }}
              >{''}</Avatar>
              <Box>
                <Typography variant="body1" sx={{ fontWeight: 500, display: 'flex', alignItems: 'center' }}>
                  {g.name}
                  {isBuddyOfDay && (
                    <Box component="span" sx={{ ml: 1, color: '#ffd700', fontWeight: 'bold', fontSize: 16 }}>
                      ★ Buddy of the Day
                    </Box>
                  )}
                </Typography>
                <Typography variant="body2" sx={{ color: 'text.secondary' }}>{getRotatingDesc(g.descs, tick)}</Typography>
                <Typography variant="caption" sx={{ color: 'text.disabled' }}>Count: {g.count} | Avg Energy: {avgEnergy}</Typography>
                {isBuddyOfDay && (
                  <Typography variant="caption" sx={{ color: '#c47f00', display: 'block' }}>
                    Fun fact: {g.funFact}
                  </Typography>
                )}
              </Box>
            </Box>
          );
        })}
      </Stack>
    </Paper>
  );
}