import "./globals.css";
import { AuthProvider } from "@/src/context/AuthContext";
import ChatWidget from "@/components/chatbot/ChatWidget";
import GoogleOAuthWrapper from "@/components/GoogleOAuthWrapper";

export const metadata = {
    title: "KoVoit - Covoiturage",
    description: "Application de covoiturage pour vos trajets quotidiens",
    icons: {
        icon: "/favicon.ico",
    },
};

export default function RootLayout({ children }: any) {
    return (
        <html suppressHydrationWarning>
            <body>
                <AuthProvider>
                    <GoogleOAuthWrapper>
                        {children}
                        <ChatWidget />
                    </GoogleOAuthWrapper>
                </AuthProvider>
            </body>
        </html>
    );
}
