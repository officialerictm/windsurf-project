import React, { useEffect, useRef, useState } from 'react';
import { Paper, Box, Typography, Avatar } from '@mui/material';

// Cute placeholder avatar (SVG, can be replaced with image or emoji)
const AnnouncerAvatar = () => (
  <Box sx={{ width: 48, height: 48, mr: 2, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
    <span style={{ fontSize: 40 }} role="img" aria-label="owl">🦉</span>
  </Box>
);

// Utility for random selection
function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

// Generates a fun, LLM-like commentary string based on stats and trends
function generateCommentary({ stats, prevStats, dominantHue, prevDominantHue, tick }) {
  if (!stats) return "Welcome to the Life Engine!";
  if (tick < 5) return pick([
    "Simulation starting... Let's see what happens!",
    "The world awakens. Who will thrive?",
    "Welcome, observer! The grid is alive.",
    "Our story begins..."
  ]);
  if (stats.totalPopulation === 0) return pick([
    "All organisms have perished. Nature is unforgiving!",
    "Extinction event! The grid is empty.",
    "No survivors remain. Perhaps a restart?"
  ]);
  if (stats.foodCount === 0) return pick([
    "All the food is gone! Famine strikes the land.",
    "No food left! Starvation looms.",
    "A barren wasteland—no green in sight."
  ]);
  if (stats.totalPopulation > prevStats.totalPopulation) return pick([
    `Population is booming! Now at ${stats.totalPopulation}.`,
    "A baby boom! The grid is getting crowded.",
    "Life finds a way. New organisms abound!",
    `A surge in numbers—${stats.totalPopulation} strong!`
  ]);
  if (stats.totalPopulation < prevStats.totalPopulation) return pick([
    "Population is shrinking. Survival of the fittest!",
    "A sudden die-off... who will remain?",
    "Numbers dwindle. Competition is fierce.",
    `Organisms lost! Down to ${stats.totalPopulation}.`
  ]);
  if (dominantHue !== prevDominantHue) return pick([
    `A new dominant color emerges: hue ${dominantHue}! Evolution in action.`,
    `Look out! Hue ${dominantHue} is taking over the grid!`,
    `The tides turn—hue ${dominantHue} now rules.`,
    `Evolution's paintbrush: hue ${dominantHue} leads the pack.`
  ]);
  if (stats.foodCount > prevStats.foodCount) return pick([
    "Food is plentiful again. Time for a feast!",
    "Green returns to the land. Organisms rejoice!",
    "A bumper crop of food appears!"
  ]);
  if (stats.foodCount < prevStats.foodCount) return pick([
    "Food is being eaten quickly!",
    "The grid is being devoured. Hungry times!",
    "Chomp chomp! Food is vanishing fast."
  ]);
  // Occasionally inject a philosophical or dramatic line
  if (Math.random() < 0.05) return pick([
    "Is this the dawn of a new era?",
    "Somewhere, a wise old owl ponders the meaning of life...",
    "Tensions rise as color factions battle for supremacy!",
    "History repeats itself on the grid."
  ]);
  // Filler/flavor lines
  return pick([
    "The simulation continues...",
    "Organisms roam. Who will adapt next?",
    "Peaceful for now, but change is always near.",
    "All eyes on the grid!",
    "No news is good news... or is it?"
  ]);
}

export default function Announcer({ stats, organisms, tick }) {
  const [message, setMessage] = useState('Welcome to the Life Engine!');
  const prevStats = useRef(stats);
  const prevDominantHue = useRef(null);

  // Calculate dominant organism color hue
  const hues = organisms.map(o => o.traits?.colorHue ?? 0);
  const dominantHue = hues.length > 0 ? Math.round(hues.reduce((a, b) => a + b, 0) / hues.length) : null;

  useEffect(() => {
    const msg = generateCommentary({
      stats,
      prevStats: prevStats.current,
      dominantHue,
      prevDominantHue: prevDominantHue.current,
      tick,
    });
    setMessage(msg);
    prevStats.current = stats;
    prevDominantHue.current = dominantHue;
  }, [stats, organisms, dominantHue, tick]);

  return (
    <Paper elevation={6} sx={{ position: 'fixed', bottom: 24, left: 24, display: 'flex', alignItems: 'center', p: 2, borderRadius: 3, zIndex: 1000, minWidth: 320, maxWidth: 400, bgcolor: '#fffbe7' }}>
      <AnnouncerAvatar />
      <Typography variant="body1" sx={{ fontStyle: 'italic' }}>
        {message}
      </Typography>
    </Paper>
  );
}
