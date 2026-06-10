"""Configuration Django Admin pour le module de vérification."""
from django.contrib import admin
from django.utils.html import format_html
from .models import (
    DriverProfile, DriverDocument, VerificationReport,
    AdminReview, VerificationHistory, DriverSignal,
)


@admin.register(DriverProfile)
class DriverProfileAdmin(admin.ModelAdmin):
    list_display  = ["user", "status", "is_verified", "completion_pct", "note_moyenne", "nombre_trajets", "created_at"]
    list_filter   = ["status", "is_verified"]
    search_fields = ["user__username", "user__email", "user__first_name", "user__last_name"]
    readonly_fields = ["id", "created_at", "updated_at", "verified_at", "completion_pct"]
    ordering      = ["-created_at"]

    def completion_pct(self, obj):
        pct = obj.completion_percentage
        color = "green" if pct == 100 else ("orange" if pct >= 50 else "red")
        return format_html('<span style="color:{}">{} %</span>', color, pct)
    completion_pct.short_description = "Complétion"


@admin.register(DriverDocument)
class DriverDocumentAdmin(admin.ModelAdmin):
    list_display  = ["driver_profile", "document_type", "status", "date_expiration", "uploaded_at"]
    list_filter   = ["status", "document_type"]
    search_fields = ["driver_profile__user__username"]
    readonly_fields = ["id", "uploaded_at", "verified_at", "ocr_data"]


@admin.register(VerificationReport)
class VerificationReportAdmin(admin.ModelAdmin):
    list_display  = ["driver_profile", "decision", "overall_score", "fraud_score", "completed_at"]
    list_filter   = ["decision"]
    search_fields = ["driver_profile__user__username"]
    readonly_fields = ["id", "created_at", "started_at", "completed_at"]


@admin.register(AdminReview)
class AdminReviewAdmin(admin.ModelAdmin):
    list_display  = ["driver_profile", "action", "admin", "created_at"]
    list_filter   = ["action"]
    readonly_fields = ["id", "created_at"]


@admin.register(VerificationHistory)
class VerificationHistoryAdmin(admin.ModelAdmin):
    list_display  = ["driver_profile", "old_status", "new_status", "changed_by", "is_automatic", "created_at"]
    list_filter   = ["new_status", "is_automatic"]
    readonly_fields = ["id", "created_at"]


@admin.register(DriverSignal)
class DriverSignalAdmin(admin.ModelAdmin):
    list_display  = ["driver_profile", "signal_type", "reporter", "is_processed", "created_at"]
    list_filter   = ["signal_type", "is_processed"]
    search_fields = ["driver_profile__user__username", "reporter__username"]
    readonly_fields = ["id", "created_at"]
