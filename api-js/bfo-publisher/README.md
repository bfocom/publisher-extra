bfo-publisher
=============

A simple interface to a [BFO Publisher](https://publisher.bfo.com) web service.

Example (NodeJS)
---
```sh
npm install bfo-publisher
```

The module can be loaded as an ES6 module or a CommonJS module.

```js
import * as fs from "node:fs";                  // ES6
import Publisher from "bfo-publisher";          // ES6
// const fs = require("fs");                    // CommonJS
// const Publisher = require("bfo-publisher");  // CommonJS

// The message you want to send: the actions and formats
// are defined in the BFO Publisher documentation
let action = "convert";
let message = {
    put: [
        {
          content: fetch("http://example.com/test.html")
        },
        {
          content: "body { margin: 0 }",
          path: "my-stylesheet.css",
          content_type: "text/css"
        },
        {
          content: new Blob([myuint8array], { type: "image/png" }),
          path: "my-image.png"
        }
    ]
};

// Send a message, wait for the response, process it.
// Multiple messages can be sent; call disconnect() when finished
const publisher = new Publisher("http://localhost:8080/");
publisher.build(action, message).send().then((response) => {
    fs.writeFileSync("out.pdf", response.content);
}).finally(() => {
    publisher.disconnect();
});
```

Example (Browser)
---

Non-module use in a browser is shown here - the code defines two classes (`Publisher` and `PublisherMessage`).
Any `HTMLDocument` or `XMLDocument` can be specified in a browser as a `content` object for conversion.
This example shows how to make a button to download the current page as a PDF

```html
<!DOCTYPE html>
<html>
 <head>
  <script src="https://publisher.bfo.com/public/publisher.js"></script>
  <script>
   const publisher = new Publisher("http://localhost:8080/");
   function convert(e) {
     let src = e.srcElement;
     publisher.build("convert", {
       put: [ { content: document } ]
     }).send().then((response) => {
       let a = document.createElement("a");
       let blob = new Blob([response.content],{type:response.content_type});
       a.href = URL.createObjectURL(blob);
       a.download = "file.pdf";
       a.addEventListener("click", (e) => {
         setTimeout(() => { URL.revokeObjectURL(a.href); }, 500);
         return true;
       });
       a.click();
     }).catch((e) => {
       console.log(e);
     });
   }
   function initialize() {
     document.getElementById("button").addEventListener("click", convert);
   }
   window.addEventListener("DOMContentLoaded", initialize);
  </script>
 </head>
 <body>
  <button id="button">Download this page as a PDF</button>
 </body>
</html>
```

It can also be used as an ES6 module in a browser like this:

```html
<script type="module">
 import Publisher from "https://publisher.bfo.com/public/publisher-module.js";
 const publisher = new Publisher("http://localhost:8080/");
 // ... etc
</script>
```

The code uses the the browser WebSocket implementation, so has no dependencies.
We **strongly** recommend you host the script yourself for production use.

Detail
---

The API is a simple wrapper around the [BFO Publisher Web Service](https://publisher.bfo.com/live/help/#_web_service),
which can be downloaded and run (locally or on another server; all the examples on this page assume it's accessible
at `http://localhost:8080/`).

To use the API:

1. Create a new `Publisher` object
2. Call `build(type, parameters)`, where `type` is one of the actions described in the web-service: usually this will
   be `convert`
3. Call `send()` on the returned object. This returns a Promise which will resolve with the responses to your request.
   If the server responds with an error, the Promise is rejected.
4. Repeat as required; multiple messages can be sent at once. When done call `publisher.disconnect()` to close the socket.

The object returned from `send()` is also an `EventTarget` and will emit `log` events if the action was `convert`.
The message formats are [fully described](https://publisher.bfo.com/live/help/#_web_service)
in the BFO Publisher documentation, but with some minor additions to make life easier:

* The `content` key (for content being sent to BFO Publisher for conversion) can be specified as a `string`, `Uint8Array`
  or `ArrayBuffer`, or as a Promise that will eventually return one of those (from a `Blob` or a `fetch()`, as shown in the example above).

* On a browser the `content` key can be an `HTMLDocument` or `XMLDocument`. If it's the current document, the current
  document stylesheets and resources such as images are sent with the request. Scripts are not sent (they're not processed by BFO Publisher).
  The document is sent as it currently is, so will reflect any changes to the DOM after the file was loaded.

The `Publisher` class takes a URL in the constructor, but can also accept an object with the following keys for configuration

* `url` - the URL of the Publisher instance. Required
* `authorization` - an [Authorization key](https://publisher.bfo.com/live/help/#_access_control) which will be used
 as the default for every message.
* `min_backoff` - if the server is disconnected or fails to connect, the number of milliseconds before it's retried.
* `max_backoff` - if the server doesn't reconnect on the first attempt, the delay will be quadrupled on every attempt until
* `callback` - a callback function which will be called if the server sends a callback to request authorization to access
a URL - typically a username and password. The method should modify the supplied list of callbacks in place and return.

The `url` (string) and `connected` (boolean) properties on the `Publisher` object show the current state of the connection.
