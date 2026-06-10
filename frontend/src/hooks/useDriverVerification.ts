import { useEffect, useState } from "react";
import { useAuth } from "./useAuth";
import { getVerificationStatus, type VerificationStatus } from "@/src/services/verification.service";

export type DriverVerificationState = {
  status: VerificationStatus | null;
  loading: boolean;
  isActive: boolean;
  isBlocked: boolean;
  isPending: boolean;
  needsDocuments: boolean;
  canPublishTrip: boolean;
  refresh: () => void;
};

export function useDriverVerification(): DriverVerificationState {
  const { user } = useAuth();
  const [status, setStatus] = useState<VerificationStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [tick, setTick] = useState(0);

  useEffect(() => {
    if (!user || user.role !== "conducteur") {
      setLoading(false);
      return;
    }
    setLoading(true);
    getVerificationStatus()
      .then(setStatus)
      .catch(() => setStatus(null))
      .finally(() => setLoading(false));
  }, [user, tick]);

  const st = status?.status ?? user?.driver_status ?? "DOCUMENTS_MISSING";

  return {
    status,
    loading,
    isActive:       st === "ACTIVE",
    isBlocked:      st === "BLOCKED",
    isPending:      st === "PENDING_AI_REVIEW" || st === "PENDING_ADMIN_REVIEW",
    needsDocuments: st === "DOCUMENTS_MISSING" || st === "DRAFT",
    canPublishTrip: st === "ACTIVE" && (status?.is_verified ?? false),
    refresh: () => setTick((t) => t + 1),
  };
}
