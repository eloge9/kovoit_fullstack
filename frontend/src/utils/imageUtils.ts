/**
 * Utilitaires pour la gestion des images
 */

export const getMediaUrl = (path?: string | null): string => {
    if (!path) {
        return '';
    }
    
    // Si l'URL est déjà complète (commence par http), la retourner telle quelle
    if (path.startsWith('http')) {
        return path;
    }
    
    // Si l'URL commence par /media/, construire l'URL complète
    if (path.startsWith('/media/')) {
        return `http://127.0.0.1:8000${path}`;
    }
    
    // Si l'URL commence par media/ (sans / au début)
    if (path.startsWith('media/')) {
        return `http://127.0.0.1:8000/${path}`;
    }
    
    // Sinon, considérer que c'est un chemin relatif vers media
    return `http://127.0.0.1:8000/media/${path}`;
};

export const getUserPhotoUrl = (photoProfil?: string | null): string => {
    return getMediaUrl(photoProfil);
};
