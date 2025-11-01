from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from .models import FastSession
from .serializers import FastSessionSerializer

class FastSessionViewSet(viewsets.ModelViewSet):
    queryset = FastSession.objects.all()
    serializer_class = FastSessionSerializer
    permission_classes = [IsAuthenticated]
