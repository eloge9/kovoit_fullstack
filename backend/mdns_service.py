"""
Publication mDNS (Zeroconf/Bonjour) du backend Kovoit sur le réseau local.
Le téléphone peut ainsi découvrir automatiquement l'IP du serveur sans configuration.
"""
import atexit
import socket
import threading

_zeroconf = None
_info = None
_lock = threading.Lock()


def get_local_ip() -> str:
    """Retourne l'IP LAN réelle du serveur (pas 127.0.0.1)."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(1)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def start_mdns(port: int = 8000) -> None:
    """Publie le service Kovoit via mDNS. Idempotent."""
    global _zeroconf, _info
    with _lock:
        if _zeroconf is not None:
            return
        try:
            from zeroconf import ServiceInfo, Zeroconf

            ip = get_local_ip()
            _zeroconf = Zeroconf()
            _info = ServiceInfo(
                "_http._tcp.local.",
                "Kovoit._http._tcp.local.",
                addresses=[socket.inet_aton(ip)],
                port=port,
                properties={
                    "service": b"kovoit-backend",
                    "version": b"1",
                },
                server="kovoit.local.",
            )
            _zeroconf.register_service(_info)
            print(f"[mDNS] Kovoit publié sur {ip}:{port} (Kovoit._http._tcp.local.)")
            atexit.register(stop_mdns)
        except ImportError:
            print("[mDNS] Package 'zeroconf' manquant — pip install zeroconf")
        except Exception as exc:
            print(f"[mDNS] Erreur démarrage: {exc}")


def stop_mdns() -> None:
    """Dépublie le service mDNS proprement."""
    global _zeroconf, _info
    with _lock:
        if _zeroconf and _info:
            try:
                _zeroconf.unregister_service(_info)
                _zeroconf.close()
                print("[mDNS] Service arrêté")
            except Exception:
                pass
            finally:
                _zeroconf = None
                _info = None
