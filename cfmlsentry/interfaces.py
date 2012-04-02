import urlparse
from django.http import QueryDict
from sentry.web.helpers import render_to_string #@UnresolvedImport
from sentry.interfaces import Interface #@UnresolvedImport


class ColdFusionHttp(Interface):
    score = 100

    # methods as defined by http://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html
    METHODS = ('GET', 'POST', 'PUT', 'OPTIONS', 'HEAD', 'DELETE', 'TRACE', 'CONNECT')

    def __init__(self, url_path, method=None, form=None, url=None, query_string=None, cookies=None, 
                sessions=None, application=None, headers=None, cgi=None, **kwargs):
        if form is None:
            form = {}

        if method:
            method = method.upper()

            assert method in self.METHODS

        urlparts = urlparse.urlsplit(url_path)

        if not query_string:
            # define querystring from url
            query_string = urlparts.query

        elif query_string.startswith('?'):
            # remove '?' prefix
            query_string = query_string[1:]

        self.url_path = '%s://%s%s' % (urlparts.scheme, urlparts.netloc, urlparts.path)
        self.method = method
        self.form = form
        self.query_string = query_string
        if application:
            self.application = application
        else:
            self.application = {}
        if url:
            self.url = url
        else:
            self.url = {}
        if sessions:
            self.sessions = sessions
        else:
            self.sessions = {}
        if cookies:
            self.cookies = cookies
        else:
            self.cookies = {}
        # if cookies were [also] included in headers we
        # strip them out
        if headers and 'Cookie' in headers:
            cookies = headers.pop('Cookie')
            if not self.cookies:
                cookies = self.cookies
        self.headers = headers or {}
        self.cgi = cgi or {}

    def serialize(self):
        return {
            'url_path': self.url_path,
            'method': self.method,
            'query_string': self.query_string,
            'form': self.form,
            'url': self.url,
            'cookies': self.cookies,
            'sessions': self.sessions,
            'application': self.application,
            'cgi': self.cgi,
            'headers': self.headers,
        }

    def to_string(self, event):
        return render_to_string('sentry/partial/interfaces/cfmlhttp.txt', {
            'event': event,
            'full_url': '?'.join(filter(bool, [self.url_path, self.query_string])),
            'url_path': self.url_path,
            'method': self.method,
            'query_string': self.query_string,
        })

    def to_html(self, event):
        form = self.form
        data_is_dict = False
        if self.headers.get('Content-Type') == 'application/x-www-form-urlencoded':
            try:
                form = QueryDict(form)
            except:
                pass
            else:
                data_is_dict = True

        # It's kind of silly we store this twice
        cookies = self.cookies or self.headers.pop('Cookie', {})
        cookies_is_dict = isinstance(cookies, dict)
        if not cookies_is_dict:
            try:
                cookies = QueryDict(cookies)
            except:
                pass
            else:
                cookies_is_dict = True

        return render_to_string('sentry/partial/interfaces/cfmlhttp.html', {
            'event': event,
            'full_url': '?'.join(filter(bool, [self.url_path, self.query_string])),
            'url_path': self.url_path,
            'method': self.method,
            'url': self.url,
            'form': form,
            'data_is_dict': data_is_dict,
            'query_string': self.query_string,
            'application': self.application,
        'sessions': self.sessions,
            'cookies': cookies,
            'cookies_is_dict': cookies_is_dict,
            'headers': self.headers,
            'cgi': self.cgi,
        })

    def get_search_context(self, event):
        return {
            'filters': {
                'url_path': [self.url_path],
            }
        }

