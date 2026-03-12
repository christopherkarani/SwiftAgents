import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "export",
  basePath: "/Swarm",
  images: { unoptimized: true },
};

export default nextConfig;
