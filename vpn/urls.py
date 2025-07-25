from django.urls import path
from . import views

urlpatterns = [
    path('start-session/', views.start_session),
    path('end-session/', views.end_session),
    path('stats/', views.stats),
    path('server-config/', views.server_config),
]
