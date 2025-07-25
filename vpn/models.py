from django.db import models

# Create your models here.
from django.db import models
from django.utils import timezone

class AppUser(models.Model):
    user_id = models.CharField(max_length=100, unique=True)
    device_os = models.CharField(max_length=100)
    app_version = models.CharField(max_length=50)
    created_at = models.DateTimeField(auto_now_add=True)

class Session(models.Model):
    user = models.ForeignKey(AppUser, on_delete=models.CASCADE)
    start_time = models.DateTimeField(default=timezone.now)
    end_time = models.DateTimeField(null=True, blank=True)
    bytes_sent = models.BigIntegerField(default=0)
    bytes_received = models.BigIntegerField(default=0)
    active = models.BooleanField(default=True)

class AppInstall(models.Model):
    user = models.ForeignKey(AppUser, on_delete=models.CASCADE)
    installed_at = models.DateTimeField(auto_now_add=True)
    os_version = models.CharField(max_length=100)
    app_version = models.CharField(max_length=50)

class ServerConfig(models.Model):
    server_ip = models.GenericIPAddressField()
    port = models.PositiveIntegerField()
    protocol = models.CharField(max_length=10)  # e.g. 'tcp', 'udp'
    dns = models.CharField(max_length=100)
    message = models.TextField(blank=True, null=True)
    last_updated = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.server_ip}:{self.port}"
