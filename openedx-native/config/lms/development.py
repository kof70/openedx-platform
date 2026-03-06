# -*- coding: utf-8 -*-
"""
Development Django settings for Open edX LMS (Native Setup)
"""

import os
from .common import *

# ============================================================================
# DEVELOPMENT SETTINGS
# ============================================================================

DEBUG = True

ALLOWED_HOSTS = ['*']

# ============================================================================
# LOGGING CONFIGURATION (Development)
# ============================================================================

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '%(asctime)s [%(levelname)s] %(name)s [%(filename)s:%(lineno)d]: %(message)s'
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
            'level': 'DEBUG',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': False,
        },
        'django.request': {
            'handlers': ['console'],
            'level': 'DEBUG',
            'propagate': False,
        },
        'django.db.backends': {
            'handlers': ['console'],
            'level': 'DEBUG',
            'propagate': False,
        },
        'celery': {
            'handlers': ['console'],
            'level': 'DEBUG',
            'propagate': False,
        },
        '': {
            'handlers': ['console'],
            'level': 'DEBUG',
        },
    },
}

# ============================================================================
# SECURITY SETTINGS (Development - Relaxed)
# ============================================================================

SECURE_SSL_REDIRECT = False
SESSION_COOKIE_SECURE = False
CSRF_COOKIE_SECURE = False

# ============================================================================
# DEVELOPMENT TOOLS
# ============================================================================

# Show SQL queries in console (useful for debugging)
# LOGGING['loggers']['django.db.backends']['level'] = 'DEBUG'

# Email backend for development (console output)
# EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
