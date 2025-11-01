# Custom wger image with fasting extension
FROM wger/server:latest

# Copy custom extensions (build context should be project root)
COPY docker_configs/wger_extensions/fasting_extension /home/wger/src/fasting_extension

# Copy wger overrides
COPY docker_configs/wger_extensions/fasting_extension/wger_overrides/settings_extra.py /home/wger/src/wger/settings_extra.py
COPY docker_configs/wger_extensions/fasting_extension/wger_overrides/urls_extra.py /home/wger/src/wger/urls_extra.py

# Ensure permissions
USER root
RUN chown -R wger:wger /home/wger/src/fasting_extension && \
    chown wger:wger /home/wger/src/wger/settings_extra.py /home/wger/src/wger/urls_extra.py
USER wger

