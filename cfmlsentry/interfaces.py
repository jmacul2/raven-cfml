import urlparse
from django.http import QueryDict
from sentry.web.helpers import render_to_string #@UnresolvedImport
from sentry.interfaces import Interface #@UnresolvedImport


class CFMLHttp(Interface):
    score = 100

    # methods as defined by http://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html
    METHODS = ('GET', 'POST', 'PUT', 'OPTIONS', 'HEAD', 'DELETE', 'TRACE', 'CONNECT')

    def __init__(self, url_path, method=None, form=None, url=None, query_string=None, cookies=None, 
                sessions=None, application=None, headers=None, cgi=None, **kwargs):

        urlparts = urlparse.urlsplit(url_path)
        self.url_path = '%s://%s%s' % (urlparts.scheme, urlparts.netloc, urlparts.path)
        
        if method:
            self.method = method.upper()
            assert method in self.METHODS
        
        self.form = form or {}
        self.query_string = cgi.get('QUERY_STRING', '')
        self.application = application or {}
        self.url = url or {}
        self.sessions = sessions or {}
        self.cookies = cookies or {}
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
        return render_to_string('sentry/partial/interfaces/cfmlhttp.html', {
            'event': event,
            'full_url': '?'.join(filter(bool, [self.url_path, self.query_string])),
            'url_path': self.url_path,
            'method': self.method,
            'url': self.url,
            'form': self.form,
            'query_string': self.query_string,
            'application': self.application,
            'sessions': self.sessions,
            'cookies': self.cookies,
            'headers': self.headers,
            'cgi': self.cgi,
        })

    def get_search_context(self, event):
        return {
            'filters': {
                'url_path': [self.url_path],
            }
        }

