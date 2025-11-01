from django.urls import include, path

urlpatterns += [
    path("api/v2/", include("fasting_extension.urls")),
]
