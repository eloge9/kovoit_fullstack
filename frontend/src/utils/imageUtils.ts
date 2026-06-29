const BACKEND_ORIGIN = (process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:8000/api")
    .replace(/\/api\/?$/, "");

export const getMediaUrl = (path?: string | null): string => {
    if (!path) {
        return '';
    }

    if (path.startsWith('http')) {
        return path;
    }

    if (path.startsWith('/media/')) {
        return `${BACKEND_ORIGIN}${path}`;
    }

    if (path.startsWith('media/')) {
        return `${BACKEND_ORIGIN}/${path}`;
    }

    return `${BACKEND_ORIGIN}/media/${path}`;
};

export const getUserPhotoUrl = (photoProfil?: string | null): string => {
    return getMediaUrl(photoProfil);
};
