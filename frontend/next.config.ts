import type { NextConfig } from "next";

// URL du backend (sans /api) pour le CSP — ex: https://kovoit-backend.onrender.com
const backendOrigin = (process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:8000/api")
  .replace(/\/api\/?$/, "");

const securityHeaders = [
  { key: "X-Frame-Options",           value: "DENY" },
  { key: "X-Content-Type-Options",    value: "nosniff" },
  { key: "X-XSS-Protection",          value: "1; mode=block" },
  { key: "Referrer-Policy",           value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy",        value: "camera=(), microphone=(), geolocation=()" },
  {
    key:   "Strict-Transport-Security",
    value: "max-age=63072000; includeSubDomains; preload",
  },
  {
    key:   "Content-Security-Policy",
    value: [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' https://accounts.google.com",
      "style-src 'self' 'unsafe-inline' https://accounts.google.com",
      "img-src 'self' data: blob: http: https:",
      "font-src 'self' data:",
      `connect-src 'self' ${backendOrigin} ${backendOrigin.replace(/^http/, "ws")} https://accounts.google.com https: wss:`,
      "frame-src https://accounts.google.com",
      "frame-ancestors 'none'",
      "object-src 'none'",
    ].join("; "),
  },
];

const nextConfig: NextConfig = {
  images: {
    unoptimized: true,
  },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: securityHeaders,
      },
    ];
  },
};

export default nextConfig;
