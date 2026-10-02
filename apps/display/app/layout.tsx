import type { Metadata, Viewport } from "next";
import { Inter, Inter_Tight } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"], variable: "--font-body" });
const interTight = Inter_Tight({ subsets: ["latin"], variable: "--font-display" });

export const metadata: Metadata = {
  title: "WantWise Display",
  description: "The family's Want list, on the household screen.",
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  themeColor: "#0a0b0e",
  colorScheme: "dark",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en-CA" className={`${inter.variable} ${interTight.variable}`}>
      <body>{children}</body>
    </html>
  );
}
