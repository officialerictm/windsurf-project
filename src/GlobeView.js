import React, { useRef, useEffect } from 'react';
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls';

// Helper function to convert latitude/longitude to a 3D position on a sphere
function latLonToVector3(lat, lon, radius, out = new THREE.Vector3()) {
  const phi = (90 - lat) * (Math.PI / 180);
  const theta = (lon + 180) * (Math.PI / 180);

  out.x = -(radius * Math.sin(phi) * Math.cos(theta));
  out.y = radius * Math.cos(phi);
  out.z = radius * Math.sin(phi) * Math.sin(theta);

  return out;
}

// Helper function to convert grid coordinates to spherical
// and then to Cartesian coordinates on the sphere surface
const gridToSpherical = (x, y, gridSize, radius) => {
  // Map grid x to longitude (0 to gridSize-1 maps to -PI to PI)
  // Adjust longitude mapping slightly to avoid seam issues if needed
  const lon = ((x + 0.5) / gridSize) * 2 * Math.PI - Math.PI;
  // Map grid y to latitude (0 to gridSize-1 maps to PI/2 to -PI/2)
  const lat = -(((y + 0.5) / gridSize) * Math.PI - Math.PI / 2);

  // Convert spherical (lat, lon, radius) to Cartesian (x, y, z)
  // Note the Three.js coordinate system: Y is up
  const cartX = radius * Math.cos(lat) * Math.cos(lon);
  const cartY = radius * Math.sin(lat);
  const cartZ = radius * Math.cos(lat) * Math.sin(lon);

  return new THREE.Vector3(cartX, cartY, cartZ);
};

// Basic 3D globe visualization with rotation and zoom controls
export default function GlobeView({ radius = 10, width = 500, height = 500, markers = [], organisms, gridSize }) {
  const mountRef = useRef(null);
  const rendererRef = useRef();
  const sceneRef = useRef();
  const cameraRef = useRef();
  const globeRef = useRef();
  const controlsRef = useRef();
  const markerMeshesRef = useRef([]);
  const organismMarkersRef = useRef(new THREE.Group());

  useEffect(() => {
    // Renderer
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setSize(width, height);
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.setClearColor(0x11131a, 1);
    mountRef.current.appendChild(renderer.domElement);
    rendererRef.current = renderer;

    // Camera
    const camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 1000);
    camera.position.set(0, 0, radius * 2.5);
    cameraRef.current = camera;

    // Scene
    const scene = new THREE.Scene();
    sceneRef.current = scene;

    // Globe (sphere)
    const geometry = new THREE.SphereGeometry(radius, 64, 48);

    // Texture Loader
    const textureLoader = new THREE.TextureLoader();
    const earthTexture = textureLoader.load('/earth_texture_3600x1800.jpg');

    // Material with texture
    const material = new THREE.MeshPhongMaterial({
      map: earthTexture,
      color: 0xffffff,
      opacity: 0.98,
      transparent: true,
    });
    const globe = new THREE.Mesh(geometry, material);
    scene.add(globe);
    globeRef.current = globe;

    // Clear existing markers before adding new ones
    markerMeshesRef.current.forEach(markerMesh => {
      globe.remove(markerMesh);
      markerMesh.geometry.dispose();
      markerMesh.material.dispose();
    });
    markerMeshesRef.current = [];

    // Add markers
    markers.forEach(marker => {
      const markerRadius = marker.size || 0.1;
      const markerGeometry = new THREE.SphereGeometry(markerRadius, 16, 12);
      const markerMaterial = new THREE.MeshBasicMaterial({ color: marker.color || 0xff0000 });
      const markerMesh = new THREE.Mesh(markerGeometry, markerMaterial);
      
      latLonToVector3(marker.lat, marker.lon, radius, markerMesh.position);
      globe.add(markerMesh); // Add to globe so it rotates with it
      markerMeshesRef.current.push(markerMesh);
    });

    // Add the group for organism markers to the scene
    scene.add(organismMarkersRef.current);

    // Lighting
    const ambient = new THREE.AmbientLight(0xffffff, 0.7);
    scene.add(ambient);
    const dirLight = new THREE.DirectionalLight(0xffffff, 0.8);
    dirLight.position.set(10, 20, 20);
    scene.add(dirLight);

    // Simple orbit controls (manual, not three/examples)
    let dragging = false;
    let lastX = 0, lastY = 0;
    function onPointerDown(e) {
      dragging = true;
      lastX = e.clientX;
      lastY = e.clientY;
    }
    function onPointerUp() { dragging = false; }
    function onPointerMove(e) {
      if (!dragging) return;
      const dx = (e.clientX - lastX) * 0.01;
      const dy = (e.clientY - lastY) * 0.01;
      globe.rotation.y += dx;
      globe.rotation.x += dy;
      lastX = e.clientX;
      lastY = e.clientY;
    }
    function onWheel(e) {
      e.preventDefault();
      camera.position.z += e.deltaY * 0.01;
      camera.position.z = Math.max(radius * 1.1, Math.min(radius * 8, camera.position.z));
    }
    const dom = renderer.domElement;
    dom.addEventListener('pointerdown', onPointerDown);
    dom.addEventListener('pointerup', onPointerUp);
    dom.addEventListener('pointermove', onPointerMove);
    dom.addEventListener('wheel', onWheel);

    // Animation loop
    let running = true;
    function animate() {
      if (!running) return;
      renderer.render(scene, camera);
      requestAnimationFrame(animate);
    }
    animate();

    // Cleanup
    return () => {
      running = false;

      // 1. Remove event listeners from the renderer's DOM element
      if (rendererRef.current && rendererRef.current.domElement) {
        const domEl = rendererRef.current.domElement;
        domEl.removeEventListener('pointerdown', onPointerDown);
        domEl.removeEventListener('pointerup', onPointerUp);
        domEl.removeEventListener('pointermove', onPointerMove);
        domEl.removeEventListener('wheel', onWheel);
      }

      // 2. Dispose of marker meshes
      if (globeRef.current && markerMeshesRef.current) {
        markerMeshesRef.current.forEach(markerMesh => {
          globeRef.current.remove(markerMesh);
          if (markerMesh.geometry) markerMesh.geometry.dispose();
          if (markerMesh.material) markerMesh.material.dispose();
        });
      }
      markerMeshesRef.current = [];

      // 3. Dispose of the main globe mesh
      if (globeRef.current) {
        if (sceneRef.current) sceneRef.current.remove(globeRef.current); // Optional: remove from scene
        if (globeRef.current.geometry) globeRef.current.geometry.dispose();
        if (globeRef.current.material) {
          if (Array.isArray(globeRef.current.material)) {
            globeRef.current.material.forEach(mat => mat.dispose());
          } else {
            globeRef.current.material.dispose();
          }
        }
      }

      // 4. Safely remove the renderer's DOM element from the mount point
      if (mountRef.current && rendererRef.current && rendererRef.current.domElement) {
        if (mountRef.current.contains(rendererRef.current.domElement)) {
          mountRef.current.removeChild(rendererRef.current.domElement);
        }
      }

      // 5. Dispose of the renderer itself
      if (rendererRef.current) {
        rendererRef.current.dispose();
      }

      // Dispose organism markers
      if (organismMarkersRef.current) {
        organismMarkersRef.current.children.forEach(child => {
          if (child.geometry) child.geometry.dispose();
          if (child.material) child.material.dispose();
        });
        scene.remove(organismMarkersRef.current);
      }
    };
  }, [radius, width, height, markers, organisms, gridSize]);

  // Effect to update organism markers when organisms prop changes
  useEffect(() => {
    if (!organisms || !gridSize || !organismMarkersRef.current) return;

    const markersGroup = organismMarkersRef.current;
    // Clear previous markers
    while (markersGroup.children.length > 0) {
      const marker = markersGroup.children[0];
      markersGroup.remove(marker);
      // Dispose geometry and material to free up memory
      if (marker.geometry) marker.geometry.dispose();
      if (marker.material) marker.material.dispose();
    }

    const globeRadius = radius; // Should match the globe's radius
    const markerRadius = 0.05; // Size of the organism marker
    const markerGeometry = new THREE.SphereGeometry(markerRadius, 8, 6); // Simple sphere for marker

    // Add new markers
    organisms.forEach(org => {
      const position = gridToSpherical(org.x, org.y, gridSize, globeRadius);
      const markerMaterial = new THREE.MeshBasicMaterial({ color: org.color });
      const marker = new THREE.Mesh(markerGeometry, markerMaterial);
      marker.position.copy(position);

      // Optional: Make markers always face the camera (like sprites)
      // marker.lookAt(camera.position);

      markersGroup.add(marker);
    });

    // Note: We don't dispose markerGeometry here because it's shared by all markers
    // It should be disposed in the main cleanup effect if GlobeView unmounts

  }, [organisms, gridSize]); // Re-run when organisms or gridSize changes


  return (
    <div ref={mountRef} style={{ width, height, margin: '0 auto', borderRadius: '50%', overflow: 'hidden', boxShadow: '0 4px 32px #0008' }} />
  );
}
