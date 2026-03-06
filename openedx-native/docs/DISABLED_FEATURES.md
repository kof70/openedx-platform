# Disabled Features for MVP

This document lists Open edX features disabled in the MVP configuration and how to re-enable them for V2.

## Overview

The native Docker Compose setup disables several Open edX features that are not required for the MVP. This reduces complexity, improves performance, and simplifies maintenance. All disabled features can be re-enabled for V2 by following the procedures documented below.

---

## Forums and Discussions

**Status:** ❌ Disabled for MVP

**Disabled Apps:**
- `lms.djangoapps.discussion`
- `django_comment_client`
- `lms.djangoapps.django_comment_common`

**Disabled Features:**
```python
FEATURES['ENABLE_DISCUSSION_SERVICE'] = False
```

**Rationale:**
- Forums require a separate Ruby-based service (cs_comments_service)
- Adds operational complexity with Elasticsearch dependency
- MVP uses bulk email and announcements for communication

**Re-enable for V2:**

1. Deploy the forum service (cs_comments_service):
   ```yaml
   # Add to docker-compose.yml
   forum:
     image: overhangio/openedx-forum:latest
     depends_on:
       - elasticsearch
   ```

2. Add apps back to INSTALLED_APPS in `config/lms/common.py`:
   ```python
   INSTALLED_APPS += [
       'lms.djangoapps.discussion',
       'django_comment_client',
       'lms.djangoapps.django_comment_common',
   ]
   ```

3. Set feature flag in `config/lms/common.py`:
   ```python
   FEATURES['ENABLE_DISCUSSION_SERVICE'] = True
   ```

4. Configure FORUM_API_URL in environment:
   ```bash
   FORUM_API_URL=http://forum:4567
   ```

5. Run migrations:
   ```bash
   docker-compose run --rm lms python manage.py lms migrate
   ```

**Dependencies:** 
- Ruby-based forum service (cs_comments_service)
- Elasticsearch for forum search

---

## SSO Providers (Google, Microsoft, SAML)

**Status:** ❌ Disabled for MVP

**Disabled Apps:**
- `social_django`
- `common.djangoapps.third_party_auth`

**Disabled Backends:**
```python
# Removed from AUTHENTICATION_BACKENDS:
# 'social_core.backends.google.GoogleOAuth2'
# 'social_core.backends.azuread.AzureADOAuth2'
# 'common.djangoapps.third_party_auth.saml.SAMLAuthBackend'
```

**Disabled Features:**
```python
FEATURES['ENABLE_OAUTH2_PROVIDER'] = False
FEATURES['ENABLE_THIRD_PARTY_AUTH'] = False
```

**Rationale:**
- MVP uses basic username/password authentication
- Reduces external dependencies and configuration complexity
- Email verification provides sufficient security for MVP

**Re-enable for V2:**

1. Add apps to INSTALLED_APPS in `config/lms/common.py`:
   ```python
   INSTALLED_APPS += [
       'social_django',
       'common.djangoapps.third_party_auth',
   ]
   ```

2. Add authentication backends in `config/lms/common.py`:
   ```python
   AUTHENTICATION_BACKENDS += [
       'social_core.backends.google.GoogleOAuth2',
       'social_core.backends.azuread.AzureADOAuth2',
       'common.djangoapps.third_party_auth.saml.SAMLAuthBackend',
   ]
   ```

3. Set feature flags:
   ```python
   FEATURES['ENABLE_OAUTH2_PROVIDER'] = True
   FEATURES['ENABLE_THIRD_PARTY_AUTH'] = True
   ```

4. Configure OAuth2 credentials in environment:
   ```bash
   SOCIAL_AUTH_GOOGLE_OAUTH2_KEY=your_client_id
   SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET=your_client_secret
   ```

5. Run migrations:
   ```bash
   docker-compose run --rm lms python manage.py lms migrate
   ```

**Dependencies:** 
- OAuth2 provider credentials (Google, Microsoft, etc.)
- SAML IdP configuration (if using SAML)

---

## SCORM and xAPI

**Status:** ❌ Disabled for MVP

**Disabled Features:**
```python
FEATURES['ENABLE_SCORM'] = False
FEATURES['ENABLE_XAPI'] = False
```

**Rationale:**
- MVP uses native Open edX XBlocks for content
- SCORM/xAPI add complexity for advanced e-learning standards
- Not required for basic course delivery

**Re-enable for V2:**

1. Install SCORM XBlock:
   ```bash
   pip install openedx-scorm-xblock
   ```

2. Set feature flags in `config/lms/common.py`:
   ```python
   FEATURES['ENABLE_SCORM'] = True
   FEATURES['ENABLE_XAPI'] = True
   ```

3. Configure xAPI endpoint (if needed):
   ```bash
   XAPI_ENDPOINT=https://lrs.example.com/xapi
   XAPI_KEY=your_lrs_key
   XAPI_SECRET=your_lrs_secret
   ```

4. Rebuild Docker image with SCORM XBlock installed

**Dependencies:** 
- SCORM XBlock package
- Learning Record Store (LRS) for xAPI (optional)

---

## Advanced Analytics

**Status:** ❌ Disabled for MVP

**Disabled Apps:**
- `edx_analytics_dashboard` integrations
- `lms.djangoapps.analytics` (advanced features)

**Rationale:**
- MVP uses basic reporting (progress tracking, grade exports)
- Advanced analytics require separate Hadoop/Spark pipeline
- Significant infrastructure overhead

**Re-enable for V2:**

1. Deploy analytics pipeline (separate infrastructure):
   - Hadoop cluster
   - Spark processing
   - Analytics API service

2. Add analytics apps to INSTALLED_APPS:
   ```python
   INSTALLED_APPS += [
       'lms.djangoapps.analytics',
   ]
   ```

3. Configure analytics dashboard URL:
   ```bash
   ANALYTICS_DASHBOARD_URL=https://analytics.example.com
   ```

4. Configure analytics API:
   ```bash
   ANALYTICS_API_URL=https://analytics-api.example.com
   ```

**Dependencies:** 
- Hadoop/Spark analytics pipeline
- Analytics API service
- Analytics dashboard application

---

## Video Conferencing (Zoom, Teams, Jitsi)

**Status:** ❌ Disabled for MVP

**Disabled Apps:**
- Zoom LTI plugin
- Microsoft Teams integration
- Jitsi plugin

**Rationale:**
- MVP focuses on asynchronous learning
- Video conferencing adds external service dependencies
- Not required for core course delivery

**Re-enable for V2:**

1. Install video conferencing XBlock:
   ```bash
   pip install openedx-zoom-xblock
   # or
   pip install openedx-jitsi-xblock
   ```

2. Add to INSTALLED_APPS:
   ```python
   INSTALLED_APPS += [
       'zoom_xblock',
       # or 'jitsi_xblock'
   ]
   ```

3. Configure LTI credentials:
   ```bash
   ZOOM_LTI_KEY=your_zoom_lti_key
   ZOOM_LTI_SECRET=your_zoom_lti_secret
   ```

4. Rebuild Docker image with video conferencing XBlock

**Dependencies:** 
- Zoom/Teams/Jitsi account and API credentials
- LTI configuration

---

## Community Features (Teams, Wiki)

**Status:** ❌ Disabled for MVP

**Disabled Apps:**
- `lms.djangoapps.teams` (if not used for cohorts)
- `wiki` (if not needed)

**Disabled Features:**
```python
FEATURES['ENABLE_TEAMS'] = False
FEATURES['ENABLE_WIKI'] = False
```

**Rationale:**
- MVP uses cohorts for grouping (simpler)
- Wiki functionality not required for basic courses
- Reduces UI complexity

**Re-enable for V2:**

1. Add apps to INSTALLED_APPS:
   ```python
   INSTALLED_APPS += [
       'lms.djangoapps.teams',
       'wiki',
   ]
   ```

2. Set feature flags:
   ```python
   FEATURES['ENABLE_TEAMS'] = True
   FEATURES['ENABLE_WIKI'] = True
   ```

3. Run migrations:
   ```bash
   docker-compose run --rm lms python manage.py lms migrate
   ```

**Dependencies:** None (native Open edX features)

---

## Dependency Analysis

| Feature | MVP Dependencies | Safe to Disable | Impact on MVP |
|---------|------------------|-----------------|---------------|
| Forums | None (announcements use bulk_email) | ✅ Yes | No impact - alternative communication methods available |
| SSO | None (basic auth sufficient) | ✅ Yes | No impact - username/password authentication works |
| SCORM | None (using native XBlocks) | ✅ Yes | No impact - native content types sufficient |
| xAPI | None (basic grading sufficient) | ✅ Yes | No impact - standard grading works |
| Advanced Analytics | None (basic reporting sufficient) | ✅ Yes | No impact - CSV exports and dashboards available |
| Video Conferencing | None (async learning model) | ✅ Yes | No impact - asynchronous content delivery |
| Teams | None (cohorts handle grouping) | ✅ Yes | No impact - cohorts provide grouping functionality |
| Wiki | None (using course pages) | ✅ Yes | No impact - course pages provide content |

---

## Testing Disabled Features

Before disabling any feature, the following validation was performed:

1. **Dependency Analysis:** Verified no MVP functionality depends on the disabled feature
2. **Configuration Review:** Ensured INSTALLED_APPS and FEATURES are correctly configured
3. **Functional Testing:** Validated all MVP features work without the disabled features
4. **Performance Testing:** Confirmed performance improvements from reduced complexity

---

## Re-enablement Checklist

When re-enabling a feature for V2, follow this checklist:

- [ ] Review feature dependencies and prerequisites
- [ ] Update INSTALLED_APPS in Django settings
- [ ] Update FEATURES flags in Django settings
- [ ] Add required environment variables to .env
- [ ] Install required packages (if any)
- [ ] Run database migrations
- [ ] Rebuild Docker images (if needed)
- [ ] Deploy additional services (if needed)
- [ ] Test feature functionality
- [ ] Update documentation
- [ ] Train users on new feature

---

## Support

For questions about disabled features or re-enablement procedures:
- Review this document for detailed procedures
- Check the [Design Document](../design.md) for architecture decisions
- Consult the [Requirements Document](../requirements.md) for MVP scope

---

**Last Updated:** 2024
**Version:** 1.0 (MVP)
