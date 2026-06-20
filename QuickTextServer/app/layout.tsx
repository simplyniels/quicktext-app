import type { Metadata } from "next";
import "./styles.css";

export const metadata: Metadata = {
  title: "Quick Text Server",
  description: "Private family server for Quick Text",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="de">
      <body>{children}</body>
    </html>
  );
}
