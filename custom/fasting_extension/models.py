from django.db import models
from django.contrib.auth.models import User

class FastSession(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    start_time = models.DateTimeField()
    end_time = models.DateTimeField(blank=True, null=True)
    duration = models.FloatField(blank=True, null=True)
    note = models.CharField(max_length=255, blank=True)

    def save(self, *args, **kwargs):
        if self.start_time and self.end_time:
            delta = self.end_time - self.start_time
            self.duration = round(delta.total_seconds() / 3600, 2)
        super().save(*args, **kwargs)
