from django.contrib import admin
from .models import AppUser, Session, AppInstall

# Register your models here.
admin.site.register(AppUser)
admin.site.register(Session)
admin.site.register(AppInstall)
