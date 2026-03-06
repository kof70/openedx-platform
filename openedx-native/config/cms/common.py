# -*- coding: utf-8 -*-
"""
Common Django settings for Open edX CMS/Studio (Native Setup)
This file contains shared settings for both development and production.
"""

import os
from pathlib import Path

# ============================================================================
# BASE CONFIGURATION
# ============================================================================

# Service variant
SERVICE_VARIANT = os.environ.get('SERVICE_VARIANT', 'cms')

# Secret key (must be set via environment variable)
SECRET_KEY = os.environ.get('SECRET_KEY')

# Platform URLs
LMS_ROOT_URL = os.environ.get('LMS_ROOT_URL', 'http://localhost:8000')
CMS_ROOT_URL = os.environ.get('CMS_ROOT_URL', 'http://localhost:8001')
CMS_BASE = os.environ.get('CMS_HOST', 'localhost')

# ============================================================================
# DATABASE CONFIGURATION
# ============================================================================

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': os.environ.get('MYSQL_DATABASE', 'openedx'),
        'USER': os.environ.get('MYSQL_USER', 'openedx'),
        'PASSWORD': os.environ.get('MYSQL_PASSWORD'),
        'HOST': 'mysql',  # Docker service name
        'PORT': '3306',
        'OPTIONS': {
            'init_command': "SET sql_mode='STRICT_TRANS_TABLES'",
            'charset': 'utf8mb4',
        },
        'CONN_MAX_AGE': int(os.environ.get('CONN_MAX_AGE', 600)),  # Connection pooling
    }
}

# ============================================================================
# MONGODB CONFIGURATION (Modulestore)
# ============================================================================

CONTENTSTORE = {
    'ENGINE': 'xmodule.contentstore.mongo.MongoContentStore',
    'DOC_STORE_CONFIG': {
        'host': 'mongodb',
        'port': 27017,
        'db': os.environ.get('MONGO_DATABASE', 'openedx'),
        'user': os.environ.get('MONGO_USER', 'openedx'),
        'password': os.environ.get('MONGO_PASSWORD'),
        'replicaSet': 'rs0',
    }
}

MODULESTORE = {
    'default': {
        'ENGINE': 'xmodule.modulestore.mongo.MongoModuleStore',
        'DOC_STORE_CONFIG': CONTENTSTORE['DOC_STORE_CONFIG'],
        'OPTIONS': {
            'default_class': 'xmodule.hidden_module.HiddenDescriptor',
        }
    }
}

# ============================================================================
# REDIS CONFIGURATION (Caching & Sessions)
# ============================================================================

REDIS_HOST = 'redis'
REDIS_PORT = 6379

CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': f'redis://{REDIS_HOST}:{REDIS_PORT}/0',
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            'CONNECTION_POOL_KWARGS': {
                'max_connections': 50,
            }
        },
        'KEY_PREFIX': 'openedx_cms',
        'TIMEOUT': int(os.environ.get('CACHE_TIMEOUT', 300)),
    }
}

# Session configuration
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
SESSION_CACHE_ALIAS = 'default'
SESSION_COOKIE_NAME = 'sessionid_cms'
SESSION_COOKIE_SECURE = os.environ.get('SESSION_COOKIE_SECURE', 'true').lower() == 'true'

# ============================================================================
# CELERY CONFIGURATION
# ============================================================================

CELERY_BROKER_URL = os.environ.get('CELERY_BROKER_URL', f'redis://{REDIS_HOST}:{REDIS_PORT}/1')
CELERY_RESULT_BACKEND = os.environ.get('CELERY_RESULT_BACKEND', 'django-db')
CELERY_TASK_ALWAYS_EAGER = False
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TIMEZONE = 'UTC'
CELERY_TASK_ACKS_LATE = True
CELERY_TASK_REJECT_ON_WORKER_LOST = True

# ============================================================================
# INSTALLED APPS (MVP - Minimal Configuration for CMS)
# ============================================================================

INSTALLED_APPS = [
    # Django core
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    
    # Open edX core (MVP required)
    'openedx.core.djangoapps.user_api',
    'openedx.core.djangoapps.site_configuration',
    'openedx.core.djangoapps.content.course_overviews',
    'openedx.core.djangoapps.content.block_structure',
    
    # CMS apps (MVP required)
    'cms.djangoapps.contentstore',
    'cms.djangoapps.course_creators',
    'cms.djangoapps.export_course_metadata',
    
    # Third-party (MVP required)
    'rest_framework',
    'django_celery_results',
    'storages',  # For media file handling
    
    # REMOVED for MVP (V2 features):
    # 'social_django',  # SSO
]

# ============================================================================
# AUTHENTICATION BACKENDS (MVP - No SSO)
# ============================================================================

AUTHENTICATION_BACKENDS = [
    'django.contrib.auth.backends.ModelBackend',
    # SSO backends removed for MVP
]

# ============================================================================
# FEATURE FLAGS (MVP Configuration)
# ============================================================================

FEATURES = {
    # MVP ENABLED Features
    'ENABLE_EXPORT_GIT': True,
    'ENABLE_COURSE_DISCOVERY': os.environ.get('ENABLE_COURSE_DISCOVERY', 'false').lower() == 'true',
    
    # MVP DISABLED Features (V2)
    'ENABLE_OAUTH2_PROVIDER': os.environ.get('ENABLE_OAUTH2_PROVIDER', 'false').lower() == 'true',
    'ENABLE_THIRD_PARTY_AUTH': os.environ.get('ENABLE_THIRD_PARTY_AUTH', 'false').lower() == 'true',
}

# ============================================================================
# EMAIL CONFIGURATION
# ============================================================================

EMAIL_BACKEND = os.environ.get('EMAIL_BACKEND', 'django.core.mail.backends.smtp.EmailBackend')
EMAIL_HOST = os.environ.get('EMAIL_HOST', 'smtp.example.com')
EMAIL_PORT = int(os.environ.get('EMAIL_PORT', 587))
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')
EMAIL_USE_TLS = os.environ.get('EMAIL_USE_TLS', 'true').lower() == 'true'
DEFAULT_FROM_EMAIL = os.environ.get('DEFAULT_FROM_EMAIL', 'noreply@example.com')
SERVER_EMAIL = os.environ.get('SERVER_EMAIL', 'admin@example.com')

# ============================================================================
# LOCALIZATION
# ============================================================================

LANGUAGE_CODE = os.environ.get('LANGUAGE_CODE', 'fr')
TIME_ZONE = os.environ.get('TIME_ZONE', 'Europe/Paris')
USE_I18N = True
USE_L10N = True
USE_TZ = True

# Supported languages
LANGUAGES = [
    ('fr', 'Français'),
    ('en', 'English'),
]

# ============================================================================
# STATIC AND MEDIA FILES
# ============================================================================

STATIC_URL = '/static/'
STATIC_ROOT = '/openedx/staticfiles'

MEDIA_URL = '/media/'
MEDIA_ROOT = '/openedx/media'

# ============================================================================
# SECURITY SETTINGS
# ============================================================================

CSRF_COOKIE_SECURE = os.environ.get('CSRF_COOKIE_SECURE', 'true').lower() == 'true'
SECURE_SSL_REDIRECT = os.environ.get('SECURE_SSL_REDIRECT', 'false').lower() == 'true'

# ============================================================================
# MIDDLEWARE
# ============================================================================

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# ============================================================================
# TEMPLATES
# ============================================================================

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]
