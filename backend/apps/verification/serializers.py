"""Serializers DRF pour le module de vérification conducteurs."""
from rest_framework import serializers
from django.contrib.auth import get_user_model

from .models import (
    DriverProfile, DriverDocument, VerificationReport,
    AdminReview, VerificationHistory, DriverSignal,
    DriverStatus, DocumentType, DocumentStatus, REQUIRED_DOCUMENTS,
)

User = get_user_model()

ALLOWED_MIME_TYPES = {
    "image/jpeg", "image/png", "image/webp",
    "application/pdf",
}
MAX_FILE_SIZE_MB = 10


# ── Utilisateur minimal ─────────────────────────────────────────────────────
class UserMinimalSerializer(serializers.ModelSerializer):
    full_name = serializers.SerializerMethodField()

    class Meta:
        model  = User
        fields = ["id", "username", "email", "first_name", "last_name", "full_name", "photo_profil"]

    def get_full_name(self, obj):
        return f"{obj.first_name} {obj.last_name}".strip() or obj.username


# ── Document ─────────────────────────────────────────────────────────────────
class DriverDocumentSerializer(serializers.ModelSerializer):
    is_expired          = serializers.ReadOnlyField()
    days_until_expiration = serializers.ReadOnlyField()
    file_url            = serializers.SerializerMethodField()

    class Meta:
        model  = DriverDocument
        fields = [
            "id", "document_type", "status", "file_url", "file_name",
            "file_size", "file_type", "ocr_data",
            "date_emission", "date_expiration",
            "rejection_reason", "uploaded_at", "verified_at",
            "is_expired", "days_until_expiration",
        ]
        read_only_fields = [
            "id", "status", "ocr_data", "file_name", "file_size", "file_type",
            "uploaded_at", "verified_at",
        ]

    def get_file_url(self, obj):
        request = self.context.get("request")
        if obj.file and request:
            return request.build_absolute_uri(obj.file.url)
        return None


class DocumentUploadSerializer(serializers.Serializer):
    document_type = serializers.ChoiceField(choices=DocumentType.choices)
    file          = serializers.FileField()

    def validate_file(self, value):
        if value.size > MAX_FILE_SIZE_MB * 1024 * 1024:
            raise serializers.ValidationError(
                f"Fichier trop lourd ({MAX_FILE_SIZE_MB} Mo maximum)."
            )
        content_type = getattr(value, "content_type", "")
        if content_type not in ALLOWED_MIME_TYPES:
            raise serializers.ValidationError(
                "Format non accepté. Utilisez JPG, PNG, WEBP ou PDF."
            )
        return value


# ── Profil conducteur ────────────────────────────────────────────────────────
class DriverProfileSerializer(serializers.ModelSerializer):
    user                  = UserMinimalSerializer(read_only=True)
    documents             = DriverDocumentSerializer(many=True, read_only=True)
    completion_percentage = serializers.ReadOnlyField()
    can_publish_trip      = serializers.ReadOnlyField()

    class Meta:
        model  = DriverProfile
        fields = [
            "id", "user", "status", "is_verified",
            "date_naissance", "lieu_naissance", "adresse", "ville",
            "numero_permis", "categorie_permis",
            "date_emission_permis", "date_expiration_permis", "experience_annees",
            "note_moyenne", "nombre_trajets", "nombre_annulations",
            "completion_percentage", "can_publish_trip",
            "motif_suspension", "motif_rejet",
            "created_at", "updated_at", "verified_at",
            "documents",
        ]
        read_only_fields = [
            "id", "status", "is_verified", "note_moyenne",
            "nombre_trajets", "nombre_annulations",
            "completion_percentage", "can_publish_trip",
            "created_at", "updated_at", "verified_at",
        ]


class DriverProfileUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model  = DriverProfile
        fields = [
            "date_naissance", "lieu_naissance", "adresse", "ville",
            "numero_permis", "categorie_permis",
            "date_emission_permis", "date_expiration_permis", "experience_annees",
        ]


# ── Vérification report ──────────────────────────────────────────────────────
class VerificationReportSerializer(serializers.ModelSerializer):
    class Meta:
        model  = VerificationReport
        fields = [
            "id", "decision", "overall_score", "fraud_score", "confidence_score",
            "summary", "started_at", "completed_at", "processing_time_seconds",
            "ocr_report", "identity_report", "vehicle_report",
            "insurance_report", "technical_report", "fraud_report",
            "compliance_report", "created_at",
        ]
        read_only_fields = [
            "id", "decision", "overall_score", "fraud_score", "confidence_score",
            "summary", "started_at", "completed_at", "processing_time_seconds",
            "ocr_report", "identity_report", "vehicle_report",
            "insurance_report", "technical_report", "fraud_report",
            "compliance_report", "created_at",
        ]


class VerificationReportSummarySerializer(serializers.ModelSerializer):
    """Version allégée pour les listes."""
    class Meta:
        model  = VerificationReport
        fields = [
            "id", "decision", "overall_score", "fraud_score",
            "confidence_score", "completed_at", "created_at",
        ]


# ── Admin review ─────────────────────────────────────────────────────────────
class AdminReviewSerializer(serializers.ModelSerializer):
    admin = UserMinimalSerializer(read_only=True)

    class Meta:
        model  = AdminReview
        fields = ["id", "action", "motif", "notes", "admin", "created_at"]
        read_only_fields = ["id", "admin", "created_at"]


class AdminActionSerializer(serializers.Serializer):
    action = serializers.ChoiceField(choices=["APPROVE", "REJECT", "SUSPEND", "BLOCK", "REACTIVATE"])
    motif  = serializers.CharField(required=False, allow_blank=True, max_length=1000)
    notes  = serializers.CharField(required=False, allow_blank=True, max_length=2000)

    def validate(self, data):
        if data.get("action") in ["REJECT", "SUSPEND", "BLOCK"] and not data.get("motif"):
            raise serializers.ValidationError({"motif": "Le motif est obligatoire pour cette action."})
        return data


# ── Historique ───────────────────────────────────────────────────────────────
class VerificationHistorySerializer(serializers.ModelSerializer):
    changed_by = UserMinimalSerializer(read_only=True)

    class Meta:
        model  = VerificationHistory
        fields = [
            "id", "old_status", "new_status", "reason",
            "is_automatic", "changed_by", "created_at",
        ]


# ── Signalement ──────────────────────────────────────────────────────────────
class DriverSignalSerializer(serializers.ModelSerializer):
    reporter = UserMinimalSerializer(read_only=True)

    class Meta:
        model  = DriverSignal
        fields = [
            "id", "signal_type", "description", "trajet",
            "is_processed", "admin_notes", "reporter", "created_at",
        ]
        read_only_fields = ["id", "reporter", "is_processed", "admin_notes", "created_at"]


# ── Vue admin liste conducteurs ──────────────────────────────────────────────
class DriverProfileAdminListSerializer(serializers.ModelSerializer):
    user              = UserMinimalSerializer(read_only=True)
    latest_report     = serializers.SerializerMethodField()
    signals_count     = serializers.SerializerMethodField()
    completion_percentage = serializers.ReadOnlyField()

    class Meta:
        model  = DriverProfile
        fields = [
            "id", "user", "status", "is_verified",
            "completion_percentage", "note_moyenne",
            "nombre_trajets", "nombre_annulations",
            "created_at", "verified_at",
            "latest_report", "signals_count",
        ]

    def get_latest_report(self, obj):
        report = obj.verification_reports.first()
        if report:
            return VerificationReportSummarySerializer(report).data
        return None

    def get_signals_count(self, obj):
        return obj.signals.filter(is_processed=False).count()


# ── Statut vérification (vue conducteur) ────────────────────────────────────
class VerificationStatusSerializer(serializers.Serializer):
    status                = serializers.CharField()
    is_verified           = serializers.BooleanField()
    completion_percentage = serializers.IntegerField()
    can_publish_trip      = serializers.BooleanField()
    required_documents    = serializers.ListField(child=serializers.CharField())
    uploaded_documents    = serializers.ListField(child=serializers.CharField())
    missing_documents     = serializers.ListField(child=serializers.CharField())
    latest_report         = VerificationReportSummarySerializer(allow_null=True)
    motif_rejet           = serializers.CharField()
    motif_suspension      = serializers.CharField()
