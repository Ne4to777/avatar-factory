/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  
  // Разрешаем загрузку изображений из MinIO/S3 (S3_* takes precedence over MINIO_*)
  images: {
    remotePatterns: [
      {
        protocol: process.env.S3_USE_SSL === 'true' || process.env.MINIO_USE_SSL === 'true' ? 'https' : 'http',
        hostname: process.env.S3_ENDPOINT || process.env.MINIO_ENDPOINT || 'localhost',
        port: process.env.S3_PORT || process.env.MINIO_PORT || '9000',
        pathname: '/**',
      },
    ],
  },
  
  // Webpack config для исключения серверных модулей из клиентского бандла
  webpack: (config, { isServer }) => {
    if (!isServer) {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        fs: false,
        net: false,
        tls: false,
        crypto: false,
      };
    }
    
    return config;
  },
  
  // Experimental features
  experimental: {
    serverActions: {
      allowedOrigins: ['localhost:3000'],
    },
  },
};

module.exports = nextConfig;
