# This will apply the fasting_extension to the wger instance

docker exec -it HealthMan_wger python manage.py makemigrations fasting_extension
docker exec -it HealthMan_wger python manage.py migrate