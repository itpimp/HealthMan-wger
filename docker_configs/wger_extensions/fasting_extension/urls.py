from rest_framework import routers
from .api import FastSessionViewSet

router = routers.DefaultRouter()
router.register(r'fasts', FastSessionViewSet, 'fasts')
urlpatterns = router.urls
