import { ReactNode } from "react";
import { useReveal } from "../../hooks/anim";

type Props = {
  children: ReactNode;
  className?: string;
  variant?: "up" | "left" | "right";
  delay?: number;
  as?: keyof JSX.IntrinsicElements;
};

// Wraps content and animates it into view on scroll.
export default function Reveal({ children, className = "", variant = "up", delay = 0, as = "div" }: Props) {
  const { ref, shown } = useReveal<HTMLDivElement>();
  const base = variant === "up" ? "reveal" : `reveal reveal-${variant}`;
  const Tag = as as any;
  return (
    <Tag
      ref={ref}
      className={`${base} ${shown ? "is-visible" : ""} ${className}`}
      style={delay ? { transitionDelay: `${delay}ms` } : undefined}
    >
      {children}
    </Tag>
  );
}
