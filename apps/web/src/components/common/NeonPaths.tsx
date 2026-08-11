import { useEffect, useRef } from "react";
import * as THREE from "three";

/* Full-width cyberpunk neon convergence.
   Two neon streams (cyan + magenta) race from opposite edges across a dark
   grid horizon, meet and collide in a burst of light at the centre — the
   moment two paths of impact become one verified truth. */
export default function NeonPaths({ height = 420 }: { height?: number }) {
  const mountRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const mount = mountRef.current;
    if (!mount) return;

    let width = mount.clientWidth || window.innerWidth;
    const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.setSize(width, height);
    mount.appendChild(renderer.domElement);
    renderer.domElement.style.display = "block";
    renderer.domElement.style.width = "100%";
    renderer.domElement.style.height = "100%";

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(60, width / height, 0.1, 200);
    camera.position.set(0, 1.5, 11);
    camera.lookAt(0, 0, 0);

    const CYAN = 0x00e5ff;
    const MAGENTA = 0xff2bd6;

    // ── neon grid floor ───────────────────────────────────────────────
    const grid = new THREE.GridHelper(120, 60, 0x123a55, 0x0c2236);
    (grid.material as THREE.Material).transparent = true;
    (grid.material as THREE.Material).opacity = 0.5;
    grid.position.y = -3.2;
    scene.add(grid);

    // ── two converging paths on a CatmullRom curve ─────────────────────
    const curve = new THREE.CatmullRomCurve3([
      new THREE.Vector3(-16, -2.4, -6),
      new THREE.Vector3(-9, 1.6, -2),
      new THREE.Vector3(-3.5, -1.2, 1),
      new THREE.Vector3(0, 0.2, 0),
      new THREE.Vector3(3.5, 1.2, 1),
      new THREE.Vector3(9, -1.6, -2),
      new THREE.Vector3(16, 2.4, -6),
    ]);
    const basePts = curve.getPoints(300);

    function makeStream(color: number, yBend: number) {
      const pts = basePts.map((p) => new THREE.Vector3(p.x, p.y + yBend, p.z));
      const geo = new THREE.BufferGeometry().setFromPoints(pts);
      const line = new THREE.Line(geo, new THREE.LineBasicMaterial({ color, transparent: true, opacity: 0.85 }));
      line.material.blending = THREE.AdditiveBlending;
      (line.material as THREE.LineBasicMaterial).blending = THREE.AdditiveBlending;

      const head = new THREE.Mesh(
        new THREE.SphereGeometry(0.22, 20, 20),
        new THREE.MeshBasicMaterial({ color })
      );
      const glow = new THREE.Mesh(
        new THREE.SphereGeometry(0.7, 20, 20),
        new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.22, blending: THREE.AdditiveBlending })
      );
      const trail = new THREE.Mesh(
        new THREE.SphereGeometry(0.12, 12, 12),
        new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.4, blending: THREE.AdditiveBlending })
      );
      const group = new THREE.Group();
      group.add(line, head, glow, trail);
      scene.add(group);
      return { group, head, glow, trail, color };
    }

    const streamA = makeStream(CYAN, 0.35);
    const streamB = makeStream(MAGENTA, -0.35);

    // ── collision burst ───────────────────────────────────────────────
    const burst = new THREE.Mesh(
      new THREE.SphereGeometry(0.3, 28, 28),
      new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0, blending: THREE.AdditiveBlending })
    );
    scene.add(burst);

    const ring = new THREE.Mesh(
      new THREE.RingGeometry(0.4, 0.55, 48),
      new THREE.MeshBasicMaterial({ color: 0x9ffcff, transparent: true, opacity: 0, side: THREE.DoubleSide, blending: THREE.AdditiveBlending })
    );
    scene.add(ring);

    // ── floating particles ────────────────────────────────────────────
    const pCount = 140;
    const pPos = new Float32Array(pCount * 3);
    for (let i = 0; i < pCount; i++) {
      pPos[i * 3] = (Math.random() - 0.5) * 40;
      pPos[i * 3 + 1] = (Math.random() - 0.3) * 14;
      pPos[i * 3 + 2] = (Math.random() - 0.5) * 18 - 4;
    }
    const pGeo = new THREE.BufferGeometry();
    pGeo.setAttribute("position", new THREE.BufferAttribute(pPos, 3));
    const particles = new THREE.Points(
      pGeo,
      new THREE.PointsMaterial({ color: 0x66e0ff, size: 0.08, transparent: true, opacity: 0.7, blending: THREE.AdditiveBlending })
    );
    scene.add(particles);

    const clock = new THREE.Clock();
    let raf = 0;
    const speed = 0.16;

    const animate = () => {
      const t = clock.getElapsedTime();
      const fA = (t * speed) % 1;
      const fB = 1 - ((t * speed) % 1);
      const iA = Math.min(basePts.length - 1, Math.floor(fA * (basePts.length - 1)));
      const iB = Math.min(basePts.length - 1, Math.floor(fB * (basePts.length - 1)));
      const pa = basePts[iA]; const pb = basePts[iB];
      streamA.head.position.set(pa.x, pa.y + 0.35, pa.z);
      streamA.glow.position.copy(streamA.head.position);
      streamA.trail.position.set(basePts[Math.max(0, iA - 6)].x, basePts[Math.max(0, iA - 6)].y + 0.35, basePts[Math.max(0, iA - 6)].z);
      streamB.head.position.set(pb.x, pb.y - 0.35, pb.z);
      streamB.glow.position.copy(streamB.head.position);
      streamB.trail.position.set(basePts[Math.min(basePts.length - 1, iB + 6)].x, basePts[Math.min(basePts.length - 1, iB + 6)].y - 0.35, basePts[Math.min(basePts.length - 1, iB + 6)].z);

      const dist = streamA.head.position.distanceTo(streamB.head.position);
      const closeness = Math.max(0, 1 - dist / 2.0);
      (burst.material as THREE.MeshBasicMaterial).opacity = closeness * 0.9;
      burst.scale.setScalar(1 + closeness * 3.5);
      (ring.material as THREE.MeshBasicMaterial).opacity = closeness * 0.8;
      ring.scale.setScalar(1 + closeness * 6);
      ring.lookAt(camera.position);

      // pulse the streams' glow with proximity
      streamA.glow.scale.setScalar(1 + closeness * 1.5);
      streamB.glow.scale.setScalar(1 + closeness * 1.5);

      scene.rotation.y = Math.sin(t * 0.15) * 0.12;
      particles.rotation.y = t * 0.02;
      (particles.material as THREE.PointsMaterial).opacity = 0.45 + 0.25 * Math.sin(t * 1.5);

      renderer.render(scene, camera);
      raf = requestAnimationFrame(animate);
    };
    animate();

    const onResize = () => {
      width = mount.clientWidth || window.innerWidth;
      renderer.setSize(width, height);
      camera.aspect = width / height;
      camera.updateProjectionMatrix();
    };
    window.addEventListener("resize", onResize);

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", onResize);
      renderer.dispose();
      if (renderer.domElement.parentNode === mount) mount.removeChild(renderer.domElement);
    };
  }, [height]);

  return <div ref={mountRef} style={{ height, width: "100%" }} aria-hidden="true" className="w-full" />;
}
