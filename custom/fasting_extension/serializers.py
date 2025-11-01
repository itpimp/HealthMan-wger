from rest_framework import serializers
from .models import FastSession

class FastSessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = FastSession
        fields = '__all__'
