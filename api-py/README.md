bfopublisher
============

This is a Python module that allows you to easily connect to a [BFO Publisher](https://publisher.bfo.com) web service.

Example
---
```sh
pip install bfopublisher
```

This example Python program demonstrates how to convert source HTML and receive a PDF document. You can supply images and other types of resource in the same way.

```python
from bfopublisher import Publisher

html = '''<!doctype html>
<html>
<head>
    <title>Example Document</title>
    <style type="text/css">
    body {
        background-color: #f0f0f2;
    }
    </style>
    <link rel="stylesheet" href="my-stylesheet.css" type="text/css">
</head>
<body>
<div class="box">
    <h1>Example Document</h1>
    <p>This is an example HTML document that will be converted to PDF.</p>
    <p><a href="https://publisher.bfo.com">BFO Publisher</a></p>
</div>
</body>
</html>'''

my_stylesheet = '''
    .box {
        width: 600px;
        margin: 5em auto;
        padding: 2em;
        background-color: #fdfdff;
        border-radius: 0.5em;
        box-shadow: 2px 3px 7px 2px rgba(0,0,0,0.02);
    }
'''

action = 'convert'
message = {
    'put': [
        {
            'content': html,
            'content_type': 'text/html',
            'path': 'test.html'
        },
        {
            'content': my_stylesheet,
            'content-type': 'text/css',
            'path': 'my-stylesheet.css'
        }
    ]
}

def response_handler(response):
    if 'content' in response:
        print('Retrieved content of type %s' % response['content_type'])
        content = response['content']
        output_stream = open('out.pdf', 'wb')
        output_stream.write(content)
        output_stream.close()

publisher = Publisher('ws://localhost:8080/ws')
task = publisher.build(action, message)
task.set_response_handler(response_handler)
task.send()
publisher.disconnect()
```

If any of the resources referenced by your input file(s) require authorization which was not included in the original message, you will be notified via a callback. In order to support this, you will have to write a callback handler which will look like this:

```python
def callback_handler(callbacks):
    for callback in callbacks:
        print('Callback for %s' % callback['prompt'])
        callback_type = callback['type']
        value = input('Please enter the value for \'%s\': ' % callback_type)
        callback[callback_type] = value
    return callbacks
```

You will also need to register the callback handler on each task you create before calling `send()`:

```python
task.set_callback_handler(callback_handler)
```

Of course you can use any method you like to supply the values. If you supply the wrong credentials, you will receive another callback on your handler. If you don't specify a callback handler, you will receive a warning and the conversion process will continue as if the resource it tried to access was absent.

The bfopublisher module depends on the cbor2 and websocket-client external Python modules which should be installed by pip.

Detail
---
The bfopublisher module is a simple Python wrapper around the [BFO Publisher Web Service](https://publisher.bfo.com/live/help/#_web_service),
which can be downloaded and run (locally or on another server; all the examples on this page assume it's accessible
at `http://localhost:8080/`). Note the ws: scheme on the URL to access the web service in the code as well as the final "ws" in the path, to access it via the websockets protocol.

To use the API:

1. Create a new `Publisher` object
2. call `build(action, message)`, where `action` is one of the actions described in the [web service documentation](https://publisher.bfo.com/live/help/#_webservice_reference). Usually this will be `convert`, you can also use `status`. This returns a task object associated with that message.
3. set the callback method for that task. It takes a response object which will be a dictionary. Different tasks can be assigned different callbacks to handle their results.
4. call `send()` on the task to send the message and process the responses. A convert action will produce numerous responses. One of them will be of type `convert-response` and contain the content output, others may be progress log messages. You can run many tasks in parallel over the same websocket connection for lengthy conversions, and the responses will be multiplexed back to the callbacks you specify. More information about conversion responses is [here](https://publisher.bfo.com/live/help/#_websockets).
5. Ensure that `disconnect()` is called on the Publisher object when you're done, to close the connection.

The Publisher class takes a websockets URL in its constructor. You can also specify an `authorization` parameter, which is an [authorization key](https://publisher.bfo.com/live/help/#_access_control) for access control.

