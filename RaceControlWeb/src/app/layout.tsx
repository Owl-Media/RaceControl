import type { Metadata } from "next";
import { Suspense } from "react";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { NavBar } from "@/components/NavBar";
import { Footer } from "@/components/Footer";
import { FavoritesProvider } from "@/components/FavoritesProvider";
import { HelpDrawerProvider } from "@/components/HelpDrawerProvider";
import { HelpDrawer } from "@/components/HelpDrawer";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "RaceControl",
  description: "Historical Formula 1 schedules, results, standings, and telemetry.",
  icons: {
    icon: [
      { url: "/icon-32.png", sizes: "32x32", type: "image/png" },
      { url: "/icon-192.png", sizes: "192x192", type: "image/png" },
    ],
    shortcut: ["/favicon.ico"],
    apple: [{ url: "/apple-touch-icon.png", sizes: "180x180", type: "image/png" }],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col bg-background text-foreground">
        <FavoritesProvider>
          <HelpDrawerProvider>
            <NavBar />
            <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-6">{children}</main>
            <Footer />
            <Suspense fallback={null}>
              <HelpDrawer />
            </Suspense>
          </HelpDrawerProvider>
        </FavoritesProvider>
      </body>
    </html>
  );
}
