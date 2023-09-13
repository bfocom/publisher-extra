from io import BytesIO
import cbor2
import sys
import urllib.parse
import uuid
import websocket

class PublisherTask:
    """
    An individual task for the web service to process. Typically consists of one request and response,
    but there may be more messages depending on the type of action and whether authorization callbacks are required.
    """

    MAX_FRAME_LENGTH = 65536

    def __init__(self, publisher, action, message):
        """
        Constructor. Do not call this directly, use Publisher.build to retreieve an instance of this class.
        """
        self.publisher = publisher
        self.action = action
        self.message = message
        self.response_handler = None
        self.callback_handler = None
        self.id = str(uuid.uuid4())
        if publisher.connection is None:
            publisher.connection = websocket.create_connection(publisher.url)
    def set_response_handler(self, response_handler):
        """
        Set the response handler for receiving response messages.
        """
        self.response_handler = response_handler
    def set_callback_handler(self, callback_handler):
        """
        Set the callback handler for providing authorization callback information.
        """
        self.callback_handler = callback_handler
    def send(self):
        """
        Send the task to the web service. This should only be called once. Results are delivered to the response handler.
        """
        message = {}
        message['type'] = self.action
        if self.publisher.authorization is not None:
            message['authorization'] = self.publisher.authorization
        message['message_id'] = self.id
        for key in self.message:
            value = self.message[key]
            if 'content' == key and isinstance(value, str):
                value = value.encode('utf-8')
            message[key] = value
        #print('>>> %s' % message)
        request = cbor2.dumps(message)
        # Handle framing for large messages
        if len(request) > PublisherTask.MAX_FRAME_LENGTH:
            head = request[:PublisherTask.MAX_FRAME_LENGTH]
            request = request[PublisherTask.MAX_FRAME_LENGTH:]
            frame = websocket.ABNF.create_frame(head, websocket.ABNF.OPCODE_BINARY, 0)
            self.publisher.connection.send_frame(frame)
            while len(request) > PublisherTask.MAX_FRAME_LENGTH:
                head = request[:PublisherTask.MAX_FRAME_LENGTH]
                request = request[PublisherTask.MAX_FRAME_LENGTH:]
                frame = websocket.ABNF.create_frame(head, websocket.ABNF.OPCODE_CONT, 0)
                self.publisher.connection.send_frame(frame)
            frame = websocket.ABNF.create_frame(request, websocket.ABNF.OPCODE_CONT, 1)
            self.publisher.connection.send_frame(frame)
        else:
            self.publisher.connection.send_binary(request)
        complete = False
        while not complete:
            frame = self.publisher.connection.recv_frame()
            data = frame.data
            while frame.fin == 0: # handle continuation frames
                frame = self.publisher.connection.recv_frame()
                data = data + frame.data
            response = cbor2.loads(data)
            #print('<<< %s' % data)
            if response['reply_to'] != self.id:
                continue
            if not response['ok']:
                raise Exception('Web service returned error: %s' % str(response))
            if self.action == 'convert':
                if 'complete' in response:
                    complete = response['complete']
            else:
                complete = True
            response_type = response['type']
            if response_type == 'callback':
                callback_response = {}
                callback_response['type'] = 'callback-response'
                callback_response['reply_to'] = response['reply_to']
                callback_response['callback_id'] = response['callback_id']
                callbacks = response['callbacks']
                if self.callback_handler is not None:
                    callbacks = self.callback_handler(callbacks)
                else:
                    callbacks = []
                    sys.stderr.write('Callback required to access resource, but callback_handler not set!\n')
                callback_response['callbacks'] = callbacks
                callback_response_request = cbor2.dumps(callback_response)
                self.publisher.connection.send_binary(callback_response_request)
            elif self.response_handler is not None:
                self.response_handler(response)

class Publisher:
    """
    Top-level interface to a BFO Publisher web service.
    """
    def __init__(self, url, authorization=None):
        """
        Constructor.

        Parameters
        ----------
        url: the URL of the Web service to connect to
        authorization: an authorization key to use
        """
        if url.startswith('http:'):
            url = 'ws:' + url[5:]
        elif url.startswith('https:'):
            url = 'wss:' + url[6:]
        if not url.endswith('/ws'):
            if url.endswith('/'):
                url = url + 'ws'
            else:
                url = url + '/ws'
        self.url = url
        self.authorization = authorization
        url_comps = urllib.parse.urlparse(url)
        self.scheme = url_comps.scheme
        self.host = url_comps.netloc
        self.port = None
        self.path = url_comps.path
        lsi = self.path.rindex('/')
        self.path = self.path[:lsi + 1]
        self.connection = None
        host_comps = self.host.split(':', 1)
        if len(host_comps) > 1:
            self.port = int(host_comps[1])
            self.host = host_comps[0]
    def build(self, action, message):
        """
        Create a new task for the web service with the specified action and message.

        Parameters
        ----------
        action: the type of task for the web service to perform, currently 'convert' or 'status'
        message: a dictionary containing the message for the task. See BFO Publisher web service documentation for details.
        """
        return PublisherTask(self, action, message)
    def disconnect(self):
        """
        Closes the web service connection.
        """
        if self.connection is not None:
            self.connection.close()
            self.connection = None

