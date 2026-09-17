/** 18x18 stroke icon from docs/prototype.html path data. Decorative: always aria-hidden. */
export function Icon({ paths, size = 18 }: { paths: string; size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 18 18"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.4"
      aria-hidden="true"
      dangerouslySetInnerHTML={{ __html: paths }}
    />
  );
}
