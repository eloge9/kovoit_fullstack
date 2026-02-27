import "./globals.css";
import { AuthProvider } from "@/src/context/AuthContext";


export default function RootLayout({ children }: any) {
    return (
        <html>
        <body>
        <AuthProvider>{children}</AuthProvider>
        </body>
        </html>
    );
}
