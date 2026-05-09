'use client';

import { useEffect, useState } from 'react';
import { Bell, X, CheckCircle, AlertTriangle, Info } from 'lucide-react';

interface Notification {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  title: string;
  message: string;
  timestamp: Date;
  read: boolean;
}

export default function NotificationSystem() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [showNotifications, setShowNotifications] = useState(false);

  // Ajouter une notification
  const addNotification = (notification: Omit<Notification, 'id' | 'timestamp' | 'read'>) => {
    const newNotification: Notification = {
      ...notification,
      id: Date.now().toString(),
      timestamp: new Date(),
      read: false,
    };

    setNotifications(prev => [newNotification, ...prev]);

    // Auto-supprimer après 10 secondes pour les notifications de succès
    if (notification.type === 'success') {
      setTimeout(() => {
        removeNotification(newNotification.id);
      }, 10000);
    }
  };

  // Supprimer une notification
  const removeNotification = (id: string) => {
    setNotifications(prev => prev.filter(n => n.id !== id));
  };

  // Marquer comme lue
  const markAsRead = (id: string) => {
    setNotifications(prev =>
      prev.map(n => n.id === id ? { ...n, read: true } : n)
    );
  };

  // Compter les notifications non lues
  const unreadCount = notifications.filter(n => !n.read).length;

  // Écouter les événements de notification
  useEffect(() => {
    const handleTrajetCommence = (event: any) => {
      addNotification({
        type: 'info',
        title: 'Trajet commencé',
        message: event.detail?.message || 'Le conducteur a commencé le trajet',
      });
    };

    const handleTrajetTermine = (event: any) => {
      addNotification({
        type: 'success',
        title: 'Trajet terminé',
        message: event.detail?.message || 'Le trajet est terminé',
      });
    };

    const handlePositionUpdate = (event: any) => {
      addNotification({
        type: 'info',
        title: 'Position mise à jour',
        message: 'La position du véhicule a été mise à jour',
      });
    };

    // Écouter les événements personnalisés
    window.addEventListener('trajet-commence', handleTrajetCommence);
    window.addEventListener('trajet-termine', handleTrajetTermine);
    window.addEventListener('position-update', handlePositionUpdate);

    return () => {
      window.removeEventListener('trajet-commence', handleTrajetCommence);
      window.removeEventListener('trajet-termine', handleTrajetTermine);
      window.removeEventListener('position-update', handlePositionUpdate);
    };
  }, []);

  // Rendre l'icône de notification
  const getNotificationIcon = (type: Notification['type']) => {
    switch (type) {
      case 'success':
        return <CheckCircle className="w-5 h-5 text-green-500" />;
      case 'error':
        return <AlertTriangle className="w-5 h-5 text-red-500" />;
      case 'warning':
        return <AlertTriangle className="w-5 h-5 text-yellow-500" />;
      case 'info':
        return <Info className="w-5 h-5 text-blue-500" />;
    }
  };

  // Formater la date
  const formatTime = (date: Date) => {
    return date.toLocaleTimeString('fr-FR', {
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <>
      {/* Bouton de notification */}
      <div className="fixed top-4 right-4 z-50">
        <button
          onClick={() => setShowNotifications(!showNotifications)}
          className="relative p-3 bg-white rounded-full shadow-lg hover:shadow-xl transition-shadow"
        >
          <Bell className="w-6 h-6 text-gray-600" />
          {unreadCount > 0 && (
            <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full w-5 h-5 flex items-center justify-center">
              {unreadCount}
            </span>
          )}
        </button>
      </div>

      {/* Panneau de notifications */}
      {showNotifications && (
        <div className="fixed top-20 right-4 z-50 w-96 bg-white rounded-lg shadow-xl max-h-96 overflow-hidden">
          <div className="p-4 border-b flex items-center justify-between">
            <h3 className="font-semibold text-gray-800">Notifications</h3>
            <button
              onClick={() => setShowNotifications(false)}
              className="text-gray-400 hover:text-gray-600"
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          <div className="max-h-80 overflow-y-auto">
            {notifications.length === 0 ? (
              <div className="p-8 text-center text-gray-500">
                <Bell className="w-12 h-12 mx-auto mb-3 text-gray-300" />
                <p>Aucune notification</p>
              </div>
            ) : (
              <div className="divide-y">
                {notifications.map((notification) => (
                  <div
                    key={notification.id}
                    className={`p-4 hover:bg-gray-50 cursor-pointer transition-colors ${!notification.read ? 'bg-blue-50' : ''
                      }`}
                    onClick={() => {
                      markAsRead(notification.id);
                    }}
                  >
                    <div className="flex items-start space-x-3">
                      {getNotificationIcon(notification.type)}
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <p className="font-medium text-gray-900 truncate">
                            {notification.title}
                          </p>
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              removeNotification(notification.id);
                            }}
                            className="text-gray-400 hover:text-gray-600 ml-2"
                          >
                            <X className="w-4 h-4" />
                          </button>
                        </div>
                        <p className="text-sm text-gray-600 mt-1">
                          {notification.message}
                        </p>
                        <p className="text-xs text-gray-400 mt-2">
                          {formatTime(notification.timestamp)}
                        </p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Notifications toast (pour les notifications récentes) */}
      <div className="fixed bottom-4 right-4 z-50 space-y-2">
        {notifications.slice(0, 3).map((notification) => (
          !notification.read && (
            <div
              key={notification.id}
              className="bg-white rounded-lg shadow-lg p-4 min-w-80 max-w-sm animate-pulse"
            >
              <div className="flex items-start space-x-3">
                {getNotificationIcon(notification.type)}
                <div className="flex-1">
                  <p className="font-medium text-gray-900">
                    {notification.title}
                  </p>
                  <p className="text-sm text-gray-600 mt-1">
                    {notification.message}
                  </p>
                </div>
                <button
                  onClick={() => removeNotification(notification.id)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            </div>
          )
        ))}
      </div>
    </>
  );
}

// Hook pour utiliser les notifications
export const useNotification = () => {
  const addNotification = (notification: Omit<Notification, 'id' | 'timestamp' | 'read'>) => {
    const event = new CustomEvent('add-notification', { detail: notification });
    window.dispatchEvent(event);
  };

  const notifyTrajetCommence = (message: string) => {
    const event = new CustomEvent('trajet-commence', { detail: { message } });
    window.dispatchEvent(event);
  };

  const notifyTrajetTermine = (message: string) => {
    const event = new CustomEvent('trajet-termine', { detail: { message } });
    window.dispatchEvent(event);
  };

  const notifyPositionUpdate = (message: string) => {
    const event = new CustomEvent('position-update', { detail: { message } });
    window.dispatchEvent(event);
  };

  return {
    addNotification,
    notifyTrajetCommence,
    notifyTrajetTermine,
    notifyPositionUpdate,
  };
};
