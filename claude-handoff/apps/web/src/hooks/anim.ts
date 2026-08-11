import { useEffect, useRef, useState } from "react";

// Reveals an element when it scrolls into view (one-shot).
export function useReveal<T extends HTMLElement = HTMLDivElement>(opts?: { threshold?: number; once?: boolean }) {
  const ref = useRef<T | null>(null);
  const [shown, setShown] = useState(false);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const io = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setShown(true);
          if (opts?.once !== false) io.disconnect();
        } else if (opts?.once === false) {
          setShown(false);
        }
      },
      { threshold: opts?.threshold ?? 0.15 }
    );
    io.observe(el);
    return () => io.disconnect();
  }, [opts?.threshold, opts?.once]);
  return { ref, shown };
}

// Counts a number up (or down) to `end` when `active` becomes true.
export function useCountUp(end: number, active: boolean, duration = 1600, decimals = 0) {
  const [value, setValue] = useState(0);
  useEffect(() => {
    if (!active) return;
    let raf = 0;
    const start = performance.now();
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / duration);
      const eased = 1 - Math.pow(1 - t, 3);
      setValue(end * eased);
      if (t < 1) raf = requestAnimationFrame(tick);
      else setValue(end);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [end, active, duration]);
  return decimals ? value.toFixed(decimals) : Math.round(value).toLocaleString();
}
