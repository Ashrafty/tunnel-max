from django.shortcuts import render

# Create your views here.
from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.utils import timezone
from .models import AppUser, Session, ServerConfig
from django.db.models import Sum, Count
from django.http import JsonResponse

@api_view(['POST'])
def start_session(request):
    user_id = request.data.get('user_id')
    os = request.data.get('device_os')
    app_version = request.data.get('app_version')

    user, created = AppUser.objects.get_or_create(user_id=user_id, defaults={
        'device_os': os,
        'app_version': app_version
    })

    session = Session.objects.create(user=user)
    return Response({'session_id': session.id, 'status': 'started'})

@api_view(['POST'])
def end_session(request):
    session_id = request.data.get('session_id')
    sent = int(request.data.get('bytes_sent', 0))
    received = int(request.data.get('bytes_received', 0))

    try:
        session = Session.objects.get(id=session_id)
        session.end_time = timezone.now()
        session.active = False
        session.bytes_sent = sent
        session.bytes_received = received
        session.save()
        return Response({'status': 'ended'})
    except Session.DoesNotExist:
        return Response({'error': 'Invalid session ID'}, status=404)

@api_view(['GET'])
def stats(request):
    connected = Session.objects.filter(active=True).count()
    total_data = Session.objects.aggregate(
        sent=Sum('bytes_sent'),
        received=Sum('bytes_received')
    )
    total_mb = ((total_data['sent'] or 0) + (total_data['received'] or 0)) / (1024 * 1024)
    return Response({
        'connected_users': connected,
        'total_data_MB': round(total_mb, 2)
    })

def stats(request):
    total_users = Session.objects.values('user_id').distinct().count()
    total_sessions = Session.objects.count()
    total_data_used = Session.objects.aggregate(Sum('data_used_mb'))['data_used_mb__sum'] or 0
    active_sessions = Session.objects.filter(end_time__isnull=True).count()

    os_stats = Session.objects.values('device_os').annotate(count=Count('device_os')).order_by('-count')
    app_stats = Session.objects.values('app_version').annotate(count=Count('app_version')).order_by('-count')

    return JsonResponse({
        'total_users': total_users,
        'total_sessions': total_sessions,
        'active_sessions': active_sessions,
        'total_data_used_mb': round(total_data_used, 2),
        'top_os_versions': list(os_stats),
        'top_app_versions': list(app_stats),
    })

def server_config(request):
    config = ServerConfig.objects.last()
    if config:
        return JsonResponse({
            "server_ip": config.server_ip,
            "port": config.port,
            "protocol": config.protocol,
            "dns": config.dns,
            "message": config.message
        })
    else:
        return JsonResponse({"error": "No config found"}, status=404)