/**
 * The Publisher class represents a connection to a BFO Publisher server instance.
 */
class Publisher extends EventTarget {

    /**
     * The list of options passed in to the constructor
     */
    options;

    /**
     * The status response returned from the server on connection
     */
    status;

    #url;
    #authorization;
    #authorization_sent;
    #browserWebSocket;
    #callbacks;
    #min_backoff;
    #max_backoff;
    #backoff;
    #socket;
    #debug;
    #callback;
    #id;
    #connected;

    /**
     * Create a new Publisher instance.
     * @param options the configuration options. If this parameter is specified as a string, it will be used as the URL.
     */
    constructor(options) {
        super();
        if (typeof(options) == "string") {
            options = {
                "url": options
            };
        }
        this.options = options;
//        options.debug_wire = true;

        if (!options.url) {
            throw new Error("No URL");
        }
        this.#url = new URL(options.url);
        this.#url.search = this.#url.hash = "";
        if (!this.#url.href.endsWith("/")) {
            this.#url.pathname += "/";
        }
        this.#debug = [];
        if (options.debug_wire) {
            this.#debug.push("wire");
        }
        this.#authorization = typeof(options.authorization) == "string" ? options.authorization : null;
        this.#callback = typeof(options.callback) == "function" ? options.callback : null;
        this.#max_backoff = typeof(options.max_backoff) == "number" ? Math.max(0, options.max_backoff) : 60000;
        this.#min_backoff = this.#max_backoff == 0 ? 0 : typeof(options.min_backoff) == "number" ? Math.max(options.min_backoff, 1) : 500;
        this.#callbacks = {};
        this.#id = 0;
        this.#connected = false;
    }

    /**
     * connected is a read-only boolean that shows the current state of the WebSocket connection
     */
    get connected() {
        return this.#connected;
    }

    /**
     * url is a read-only string that shows the URL of the WebSocket connection
     */
    get url() {
        return this.#url.href;
    }

    /**
     * Disconnect the WebSocket from the server and prevent any further connections.
     */
    disconnect() {
        this.#backoff = -1;
        this.#socket.close();
    }

    #send(msg, callback) {
        if (!this.#socket) {
            throw new Error("Socket not initialized");
        }
        if (this.#socket.readyState != 1) {
            throw new Error("Socket not connected");
        }
        msg.message_id = ++this.#id;
        this.#callbacks[msg.message_id] = callback;
        if (this.#debug.indexOf("wire") >= 0) {
            console.debug("BFO Publisher: tx", msg);
        }
        let bin = Publisher.#encodeCBOR(msg);
        this.#socket.send(bin);
    }

    #receive(msg) {
        let type;
        if (msg.data) { // browser has "msg.data", nodejs has "msg"
            msg = msg.data;
        }
        if (msg instanceof ArrayBuffer) {
            try {
                msg = Publisher.#decodeCBOR(msg);
                type = "cbor";
            } catch (e) {
                this.dispatchEvent(new CustomEvent("error", e));
                return;
            }
        } else {
            try {
                msg = JSON.parse(msg);
                type = "json";
            } catch (e) {
                this.dispatchEvent(new CustomEvent("error", e));
                return;
            }
        }
        if (this.#debug.indexOf("wire") >= 0) {
            console.debug("BFO Publisher: rx", msg);
        }
        let id = msg.reply_to;
        delete msg.reply_to;

        if (id && this.#callbacks[id]) {
            try {
                if (this.#callbacks[id].call(this, msg)) {
                    delete this.#callbacks[id];
                }
            } catch (e) {
                this.dispatchEvent(new CustomEvent("error", e));
            }
        } else {
            // Don't log these; if the callback returns true it will delete the callback
            // console.log("Unmatched reply_to=" + id);
        }
    }

    #connect() {
        const self = this;
        if (typeof(WebSocket) === "undefined") {
            // No WebSocket class means we're in NodeJS environment and need to import it.
            import("ws").then((e) => {
                globalThis.WebSocket = e.default;
                self.#connect();
            });
            return;
        }
        const path = (this.#url.protocol === "https:" ? "wss://" : "ws://") + this.#url.host + this.#url.pathname.replace(/[^\/]*$/, "") + "ws";

        // Create the socket
        this.#socket = null;
        this.#authorization_sent = null;
        if (this.#authorization) {
            // If an authorization is set at the server level, try and send it.
            // This is only valid with NodeJS "ws" module, headers can't be set
            // in the browser.
            try {
                this.#socket = new WebSocket(path, {
                    headers: {
                        "Authorization": "Bearer " + this.#authorization
                    }
                });
                this.#authorization_sent = this.#authorization;
            } catch (e) { }
        }
        if (this.#socket == null) {
            this.#socket = new WebSocket(path);
        }

        // Add the listeners
        this.#socket.binaryType = "arraybuffer";
        this.#socket.addEventListener("message", this.#receive.bind(this));
        this.#socket.addEventListener("close", function() {
            if (self.#backoff > 0) {
                self.#connected = false;
                self.dispatchEvent(new CustomEvent("disconnect"));
                setTimeout(self.#connect.bind(self), self.#backoff);
                self.#backoff = Math.max(self.#backoff * 4, self.#max_backoff);
            }
        });
        this.#socket.addEventListener("open", function() {
            self.#backoff = self.#min_backoff;
            self.#send({type: "status"}, (m) => {
                self.status = m;
                self.#connected = true;
                self.dispatchEvent(new CustomEvent("connect"));
            });
        }, {once: true});
    }

    /**
     * Build a new Message which can be sent to the server by calling <code>Message.send()</code>.
     * @param {string} type the type of 
     * @param {object} parameters for message
     * @returns {Message} a new Message object
     */
    build(type, params) {
        const self = this;
        return new PublisherMessage({
            type: type,
            params: params,
            publisher: this,
            authorization: this.#authorization,
            authorization_sent: this.#authorization_sent,
            send: this.#send,
            connect: () => {
                if (self.#socket == null) { // Lazy connection
                    self.#connect();
                }
            },
            callback:this.#callback
        });
    }

    /**
     * Encode an object as CBOR.
     * Supports boolean/numbers/bigint/strings/uint8array/list/object, as well as Date and URL
     * @param v the object to encode
     * @param out the optional object to write to; must have a write() method that writes a uint8
     * @returns the Uint8Array written to, or null if stream was passed in
     */
    static #encodeCBOR(v, stream) {
        let out;
        if (!stream) {
            out = {
                buf: new Uint8Array(256),
                len: 0,
                ensure(v) {
                    if (this.len + v > this.buf.length) {
                        let q = new Uint8Array(Math.max(this.len + v, this.buf.length + (this.buf.length >> 2)));
                        q.set(this.buf, 0);
                        this.buf = q;
                    }
                    return this;
                },
                write(v) {
                    this.buf[this.len++] = v & 0xFF;
                    return this;
                },
                writeUint8Array(v) {
                    this.ensure(v.length);
                    this.buf.set(v, this.len);
                    this.len += v.length;
                },
                complete() {
                    return this.buf.slice(0, this.len);
                }
            };
        } else if (!out.ensure || !out.complete) {
            out = {
                write(v) {
                    stream.write(v);
                },
                ensure(v) {
                    if (stream.ensure) {
                        stream.ensure(v);
                    }
                    return this;
                },
                complete(v) {
                    return null;
                }
            };
        }
        const writeObject = function(v, out, prefix) {
            if (v === false) {
                out.ensure(1).write(0xf4);
            } else if (v === true) {
                out.ensure(1).write(0xf5);
            } else if (v === null) {
                out.ensure(1).write(0xf6);
            } else if (v === undefined) {
                out.ensure(1).write(0xf7);
            } else {
                const type = typeof(v);
                if (type == "number") {
                    if (Math.floor(v) === v && Math.abs(v) <= Number.MAX_SAFE_INTEGER) {    // it's really an int, not a huge double
                        if (v < 0) {
                            prefix = 1;
                            v = -v - 1;
                        }
                        if (v < 24) {
                            out.ensure(1).write((prefix << 5) | v);
                        } else if (v <= 255) {
                            out.ensure(2).write((prefix << 5) | 24).write(v);
                        } else if (v <= 65535) {
                            out.ensure(3).write((prefix << 5) | 25).write(v>>8).write(v);
                        } else if (v <= 0x7fffffff) {
                            out.ensure(5).write((prefix << 5) | 26).write(v>>24).write(v>>16).write(v>>8).write(v);
                        } else {
                            out.ensure(9).write((prefix << 5) | 27).write(v>>56).write(v>>48).write(v>>40).write(v>>32).write(v>>24).write(v>>16).write(v>>8).write(v);
                        }
                    } else {
                        let dv = new DataView(new ArrayBuffer(8));
                        dv.setFloat32(0, v);
                        if (v == dv.getFloat32(0)) {        // can represent this exactly in 32bits
                            out.ensure(5).write(0xfa);
                            for (let i=0;i<4;i++) {
                                out.write(dv.getUint8(i));
                            }
                        } else {                            // need 64bits
                            dv.setFloat64(0, v);
                            out.ensure(9).write(0xfb);
                            for (let i=0;i<8;i++) {
                                out.write(dv.getUint8(i));
                            }
                        }
                    }
                } else if (type == "bigint") {
                    if (v <= 4294967295n && v >= -4294967296n) {    // roughly enough to catch 4-byte nums
                        writeObject(Number(v), out, prefix);
                    } else {
                        if (v < 0) {
                            prefix = 1;
                            v = -v - 1n;
                        }
                        if (v <= 0xFFFFFFFFFFFFFFFFn) {     // write as 64bit
                            out.ensure(9).write((prefix << 5) | 27);
                            for (let i=56n;i>=0;i-=8n) {
                                out.write(Number((v >> i) % 256n));
                            }
                        } else {                            // write as tagged buffer
                            let l = -1;
                            let q = v;
                            while (q > 0n) {
                                l++;
                                q >>= 8n;
                            }
                            writeObject(2 + prefix, out, 6); // tag 2
                            writeObject(l + 1, out, 2);      // buffer of length l + 1
                            out.ensure(l);
                            for (let i=BigInt(l * 8);i>=0;i-=8n) {
                                out.write(Number((v >> i) % 256n));
                            }
                        }
                    }
                } else if (type == "string") {
                    let len = v.length;
                    for (let i=0;i<v.length;i++) {
                        let c = v.codePointAt(i);
                        if (c >= 0x80) {
                            len++;
                            if (c >= 0x800) {
                                len++;
                                if (c > 0xffff) {
                                    i++;    // don't bump len, it's 2 chars already
                                }
                            }
                        }
                    }
                    writeObject(len, out, 3);
                    out.ensure(len);
                    for (let i=0;i<v.length;i++) {
                        let c = v.codePointAt(i);
                        if (c < 0x80) {
                            out.write(c);
                        } else if (c < 0x800) {
                            out.write(0xc0 | c >> 6);
                            out.write(0x80 | c & 0x3f);
                        } else if (c < 0x10000) {
                            out.write(0xe0 | c >> 12);
                            out.write(0x80 | (c >> 6)  & 0x3f);
                            out.write(0x80 | c & 0x3f);
                        } else {
                            out.write(0xf0 | c >> 18);
                            out.write(0x80 | (c >> 12)  & 0x3f);
                            out.write(0x80 | (c >> 6)  & 0x3f);
                            out.write(0x80 | c & 0x3f);
                            i++;
                        }
                    }
                } else if (Array.isArray(v)) {
                    writeObject(v.length, out, 4);
                    for (let i=0;i<v.length;i++) {
                        writeObject(v[i], out);
                    }
                } else if (v instanceof Uint8Array || v instanceof ArrayBuffer) {
                    if (v instanceof ArrayBuffer) {
                        v = new Uint8Array(v);
                    }
                    writeObject(v.length, out, 2);
                    if (out.writeUint8Array) {
                        out.writeUint8Array(v);
                    } else {
                        out.ensure(v.length);
                        for (let i=0;i<v.length;i++) {
                            out.write(v[i]);
                        }
                    }
                } else if (v instanceof Date) {     // tag0
                    writeObject(0, out, 6);
                    writeObject(v.toISOString(), out);
                } else if (v instanceof URL) {      // tag32
                    writeObject(32, out, 6);
                    writeObject(v.toString(), out);
                } else {
                    let keys = Object.keys(v);
                    writeObject(keys.length, out, 5);
                    for (let i=0;i<keys.length;i++) {
                        writeObject(keys[i], out);
                        writeObject(v[keys[i]], out);
                    }
                }
            }
        }
        writeObject(v, out, 0);
        return out.complete();
    }

    /**
     * Decode an object from a CBOR encoded source.
     * The source may be Uint8Array, or any object with a read()
     * method that returns a uint8 (and throws an Error at EOF).
     *
     * Tags are ignored except for:
     *  0,1 - converted from string/number to Date
     *  2,3 - convert from buffer to BigInt
     *  32  - convert from string to URL
     *
     * Passes all RFC8949 Appendix-A tests.
     */
    static #decodeCBOR(v) {
        if (v instanceof ArrayBuffer) {
        v = new Uint8Array(v);
        }
        if (v instanceof Uint8Array) {
            const buf = v;
            v = {
                off: 0,
                read: function() {
                    if (this.off == buf.length) {
                        throw new Error("eof");
                    }
                    return buf[this.off++];
                },
                readUint8Array: function(out) {
                    out.set(buf.slice(this.off, this.off + out.length), 0);
                    this.off += out.length;
                }
            };
        }
        const readObject = function(v, c) {
            if (c === undefined) {
                c = v.read();
            }
            const type = c>>5;
            c &= 0x1F;
            if (type == 0) {
                if (c < 24) {
                    return c;
                } else if (c == 24) {
                    return v.read();
                } else if (c == 25) {
                    return (v.read()<<8) | v.read();
                } else if (c == 26) {
                    return ((v.read()<<24) | (v.read()<<16) | (v.read()<<8) | v.read())>>>0;
                } else if (c == 27) {
                    let v1 = ((v.read()<<24) | (v.read()<<16) | (v.read()<<8) | v.read())>>>0;
                    let v2 = ((v.read()<<24) | (v.read()<<16) | (v.read()<<8) | v.read())>>>0;
                    if (v1 > Number.MAX_SAFE_INTEGER>>32) {
                        return (BigInt(v1)<<32n) | BigInt(v2);
                    } else {
                        return (v1<<32) | v2;
                    }
                } else {
                    throw new Error("Unknown integer type " + c);
                }
            } else if (type == 1) {
                let o = readObject(v, c);
                if (typeof(o) == "bigint") {
                    return -1n - o;
                } else {
                    return -1 - o;
                }
            } else if (type == 2) { // buffer
                if (c == 0x1F) {    // indefinite
                    let a = [];
                    c = v.read();
                    let totlen = 0;
                    while (c != 0xFF && (c>>5) == 2) {
                        let x = readObject(v, c);
                        a.push(x);
                        totlen += x.length;
                        c = v.read();
                    }
                    if (c != 0xFF) {
                        throw new Error("Invalid indefinite length buffer component " + c);
                    }
                    let out = new Uint8Array(totlen);
                    let j = 0;
                    for (let i=0;i<a.length;i++) {
                        out.set(a[i], j);
                        j += a[i].length;
                    }
                    return out;
                } else {            // definite
                    let len = readObject(v, c);
                    let out = new Uint8Array(len);
                    if (v.readUint8Array) {
                        v.readUint8Array(out);
                    } else {
                        for (let i=0;i<len;i++) {
                            out[i] = v.read();
                        }
                    }
                    return out;
                }
            } else if (type == 3) { // string
                if (c == 0x1F) {    // indefinite
                    let a = [];
                    c = v.read();
                    while (c != 0xFF && (c>>5) == 3) {
                        a.push(readObject(v, c));
                        c = v.read();
                    }
                    if (c != 0xFF) {
                        throw new Error("Invalid indefinite length string component " + c);
                    }
                    return a.join("");
                } else {            // definite
                    let len = readObject(v, c);
                    let buf = new Uint8Array(len);
                    if (v.readUint8Array) {
                        v.readUint8Array(buf);
                    } else {
                        for (let i=0;i<len;i++) {
                            buf[i] = v.read();
                        }
                    }
                    return new TextDecoder().decode(buf);
                }
            } else if (type == 4) { // array
                if (c == 0x1F) {    // indefinite
                    let out = new Array();
                    c = v.read();
                    while (c != 0xFF) {
                        out.push(readObject(v, c));
                        c = v.read();
                    }
                    return out;
                } else {            // definite
                    let len = readObject(v, c);
                    let out = new Array(len);
                    for (let i=0;i<len;i++) {
                        out[i] = readObject(v);
                    }
                    return out;
                }
            } else if (type == 5) { // map
                if (c == 0x1F) {    // indefinite
                    let out = {};
                    c = v.read();
                    while (c != 0xFF) {
                        let key = readObject(v, c);
                        c = v.read();
                        let val = readObject(v, c);
                        out[key] = val;
                        c = v.read();
                    }
                    return out;
                } else {            // definite
                    let len = readObject(v, c);
                    let out = {};
                    for (let i=0;i<len;i++) {
                        let key = readObject(v);
                        let val = readObject(v);
                        out[key] = val;
                    }
                    return out;
                }
            } else if (type == 6) { // tagged object
                let tag = readObject(v, c);
                let object = readObject(v);
                switch (tag) {
                    case 0:         // text string	Standard date/time string; see Section 3.4.1
                        if (typeof(object) == "string") {
                            object = new Date(object);
                        }
                        break;
                    case 1:         // integer or float	Epoch-based date/time; see Section 3.4.2
                        if (typeof(object) == "number") {
                            object = new Date(object * 1000);
                        }
                        break;
                    case 2:         // byte string     Unsigned bignum; see Section 3.4.3
                    case 3:         // byte string     Negative bignum; see Section 3.4.3
                        if (object instanceof Uint8Array) {
                            let v = 0n;
                            for (let i=0;i<object.length;i++) {
                                v = (v<<8n) | BigInt(object[i]);
                            }
                            if (tag == 3) {
                                v = -1n - v;
                            }
                            object = v;
                        }
                        break;
                    case 32:	// text string	URI; see Section 3.4.5.3
                        if (typeof(object) == "string") {
                            object = new URL(object);
                        }
                        break;
                    case 4:         // array	Decimal fraction; see Section 3.4.4
                    case 5:		// array	Bigfloat; see Section 3.4.4
                    case 21:	// (any)	Expected conversion to base64url encoding; see Section 3.4.5.2
                    case 22:	// (any)	Expected conversion to base64 encoding; see Section 3.4.5.2
                    case 23:	// (any)	Expected conversion to base16 encoding; see Section 3.4.5.2
                    case 24:	// byte string	Encoded CBOR data item; see Section 3.4.5.1
                    case 33:	// text string	base64url; see Section 3.4.5.3
                    case 34:	// text string	base64; see Section 3.4.5.3
                    case 36:	// text string	MIME message; see Section 3.4.5.3
                    case 55799:	// (any)	Self-described CBOR; see Section 3.4.6
                        break;
                }
                return object;
            } else if (c == 20) {
                return false;
            } else if (c == 21) {
                return true;
            } else if (c == 22) {
                return null;
            } else if (c == 23) {
                return undefined;
            } else if (c == 24) {
                return undefined;
            } else if (c == 25) {   // float16
                const x = readObject(v, c);
                let s = (x & 0x8000) >>> 15;
                let e = (x & 0x7c00) >>> 10;
                let f = (x & 0x3ff);
                if (e == 0) {
                    return (s != 0 ? -1.0 : 1.0) * Math.pow(2, -14) * (f / Math.pow(2, 10));
                } else if (e == 0x1F && f != 0) {
                    return Number.NaN;
                } else if (e == 0x1F && s == 0) {
                    return Number.POSITIVE_INFINITY
                } else if (e == 0x1F) {
                    return Number.NEGATIVE_INFINITY
                } else {
                    return (s != 0 ? -1.0 : 1.0) * Math.pow(2, e - 15) * (1 + f / Math.pow(2, 10));
                }
            } else if (c == 26) {   // float32
                let dv = new DataView(new ArrayBuffer(4));
                for (let i=0;i<4;i++) {
                    dv.setUint8(i, v.read());
                }
                return dv.getFloat32(0);
            } else if (c == 27) {   // float64
                let dv = new DataView(new ArrayBuffer(8));
                for (let i=0;i<8;i++) {
                    dv.setUint8(i, v.read());
                }
                return dv.getFloat64(0);
            }
            throw new Error("Invalid code " + c);
        }
        return readObject(v);
    }
}

/**
 * The Message class represents a single request to a BFO Publisher server instance.
 */
class PublisherMessage extends EventTarget {
    
    #type
    #params
    #publisher;
    #authorization;
    #authorization_sent;
    #send;
    #connect;
    #callback;

    constructor(options) {
        super();
        this.#type = options.type;
        this.#params = options.params;
        if (typeof(this.#params) != "object") {
            this.#params = {};
        }
        this.#publisher = options.publisher;
        this.#authorization = options.authorization;
        this.#authorization_sent = options.authorization_sent;
        this.#send = options.send;
        this.#connect = options.connect;
        this.#callback = options.callback;
    }

    /**
     * Process any content items for upload in the "items" array. When done, call callback()
     * @param items an array of items (the "put" array for type=convert; a manufactured 1-entry array for type=put)
     * @param type "convert" or "put"
     * @param callback function to call on success
     */
    #fixContent(items, type, callback) {
        const self = this;
        let finished = true;
        try {
            // The process is:
            //  1. Loop over every item in the "items" array
            //  2. If the item has a final type (string or Uint8Array), stop processing that item
            //  3. If the item is a promise, and if that promise hasn't been processed by this
            //     loop before (we set a __pending flag), then add a callback when that promise
            //     completes: "set the item content to the value of the promise, and call this
            //     method again". Then set finished=false - at the end of *this* method invocation,
            //     nothing will happen.
            //  4. If the item is a complex type, then evaluate it, set item.content to the result
            //     and reprocess the item.
            //
            //  Any of these options can potentially add other items to the list - for example,
            //  processing "document" might add images and stylesheets.
            //
            //  When this method runs through and doesn't wait for any promises (finished=true),
            //  call the callback.
            //
            //  Failure throws an error which should propagate up.
            // This is a messy model - yay JavaScript.
            //  
            for (let i=0;i<items.length;i++) {
                const item = items[i];
                const loc = type == "put" ? "" : "put[" + i + "].";
                let repeat = true;
                while (repeat) {
                    // Basic types: string, Uint8Array, Promise
                    if (!item.content) {
                        throw new new Error(loc + "content missing");
                        repeat = false;
                    } else if (typeof(item.content) == "string" || item.content instanceof Uint8Array) {
                        if (!item.path) {
                            if (type == "convert" && i == 0) {
                                item.path = "about:file";
                            } else {
                                throw new Error(name + ".path missing");
                            }
                        }
                        repeat = false;
                    } else if (item.content instanceof Promise) {
                        if (item.__pending) {
                        } else {
                            item.__pending = true;
                            item.content.then((v) => {
                                item.content = v;
                                delete item.__pending;
                                self.#fixContent(items, type, callback);
                            });
                        }
                        repeat = false;
                        finished = false;

                    // Special handling for particular types

                    } else if (item.content instanceof ArrayBuffer) {
                        item.content = new Uint8Array(item.content);

                    } else if (typeof Response != "undefined" && item.content instanceof Response) {  // from Fetch
                        const response = item.content;
                        // It's not our job to handle redirects - if they need processing, whowever
                        // passes us in the fetch needs to set {redirect:"follow"}
                        if (response.ok) {
                            if (!item.path) {
                                item.path = response.url;
                            }
                            item.content = response.blob(); // because blob gives us type as well
                        } else {
                            items.splice(i--, 1);      // remove the item
                            repeat = false;
                        }

                    } else if (typeof Blob != "undefined" && item.content instanceof Blob) {
                        const blob = item.content;
                        item.content = item.content.arrayBuffer();

                    } else if (typeof Buffer != "undefined" && item.content instanceof Buffer) {
                        const buffer = item.content;
                        item.content = new Uint8Array(buffer.buffer, buffer.byteOffset, buffer.length);

                    } else if ((typeof HTMLDocument != "undefined" && item.content instanceof HTMLDocument) || (typeof XMLDocument != "undefined" && item.content instanceof XMLDocument)) {
                        const doc = item.content;
                        if (!item.content_type) {
                            item.content_type = doc.contentType;
                        }
                        if (!item.path) {
                            item.path = doc.documentURI;
                        }
                        if (doc instanceof HTMLDocument) {
                            item.content = doc.documentElement.outerHTML;
                            if (type == "convert") {
                                // Add any referenced images, stylesheets, objects
                                if (doc == globalThis.document) {

                                    // The idea here is we store the stylesheets as they
                                    // are seen by the browser, the intent being to catch
                                    // any imports which are behind firewalls etc. so couldn't
                                    // be loaded by the server.
                                    //
                                    // Stylesheets from other origins won't allow us access to
                                    // "cssRules", fairly safe to presume these are public and
                                    // accessible server-side.
                                    // 
                                    let q = [ ... document.styleSheets ];
                                    for (const sheet of q) {
                                        try {
                                            sheet.cssRules;
                                        } catch (e) {
                                            continue;
                                        }
                                        if (sheet.href) {
                                            let tostring = "";
                                            for (const r of items) {
                                                if (r.path == sheet.href) {
                                                    // This stylesheet already defined
                                                    tostring = null;
                                                    break
                                                }
                                            }
                                            if (tostring != null) {
                                                let importing = true;
                                                for (const rule of sheet.cssRules) {
                                                    if (rule.styleSheet && importing) {
                                                        q.push(rule.styleSheet);
                                                    } else {
                                                        importing = false;
                                                    }
                                                    let s = rule.cssText;
                                                    if (tostring) {
                                                        tostring += "\n";
                                                    }
                                                    tostring += rule.cssText;
                                                }
                                                items.push({"path": sheet.href, "content": tostring, "content_type": sheet.type });
                                            }
                                        } else {
                                            for (const rule of sheet.cssRules) {
                                                if (rule.styleSheet) {
                                                    q.push(rule.styleSheet);
                                                } else {
                                                    break;
                                                }
                                            }
                                        }
                                    }

                                    doc.querySelectorAll("img").forEach((img) => {
                                        for (const r of items) {
                                            if (r.path == img.src) {
                                                // This img already defined
                                                img = null;
                                                break
                                            }
                                        }
                                        if (img) {
                                            items.push({ path:img.src, content: fetch(img.src) });
                                        }
                                    });
                                    // TODO picture, object, embed
                                }
                            }
                        } else {
                            item.content = new XMLSerializer().serializeToString(doc.documentElement);
                        }
                    } else {
                        throw new Error(name + ".content: unknown type " + (item.content.constructor ? item.content.constructor.name : typeof(item.content)));
                    }
                }
            }
        } catch (e) {
            console.log("fixContent failed", e);
        }
        try {
            if (finished) {
                callback();
            }
        } catch (e) {
            console.log("fixContent.callback failed", e);
        }
    }

    #verify(msg, callback) {
        if (msg.type == "convert") {
            if (!msg.put || !msg.put.length) {
                throw new Error("No put array");
            }
            this.#fixContent(msg.put, msg.type, callback);
        } else if (msg.type == "put") {
            this.#fixContent([msg], msg.type, callback);
        }
    }

    /**
     * Send the message to the BFO Publisher instance.
     * The returned object is a Promise which will be resolved with the reply when the
     * conversion completes - the promise will be passed the reply.
     */
    send() {
        const self = this;
        const req = {};
        req.type = this.#type;
        if (this.#authorization && this.#authorization != this.#authorization_sent) {
            req.authorization = this.#authorization;
        }
        for (const [k, v] of Object.entries(this.#params)) {
            if (k != "authorization" || v != this.#authorization_sent) {
                req[k] = v;
            }
        }
        return new Promise((resolve, reject) => {
            this.#verify(req, () => {
                new Promise((resolve, reject) => {
                    self.#connect();
                    if (self.#publisher.connected) {
                        resolve();
                    } else {
                        self.#publisher.addEventListener("connect", () => {
                            resolve();
                        });
                    }
                }).then(() => {
                    self.#send.call(self.#publisher, req, (res) => {
                        let done = false;
                        res.request = req;
                        if (!res.ok) {
                            let err = new Error(res.message ? res.message : "Failed");
                            err.response = res;
                            self.dispatchEvent(new CustomEvent("error", err));
                            reject(err);
                            done = true;
                        } else if (res.type == "log") {
                            self.dispatchEvent(new CustomEvent("log", res.log));
                        } else if (res.type == req.type + "-response") {
                            if (!res.complete) {
                                self.dispatchEvent(new CustomEvent("update", res));
                            } else {
                                if (res.content) {
                                    res.blob = () => {
                                        return new Blob([res.content], { "type": res.content_type });
                                    };
                                }
                                self.dispatchEvent(new CustomEvent("complete", res));
                                resolve(res);
                                done = true;
                            }
                        } else if (type == "callback") {
                            // This will always send a callback-response,
                            // even if no callback data is available.
                            // The conversion will fail and we'll get a
                            // message back from the server.
                            let response = null;
                            if (this.#callback) {
                                response = this.#callback(m.callbacks);
                            }
                            if (!response) {
                                response = m.callbacks;
                            }
                            self.publisher.send({
                                "type": "callback-response",
                                "callback_id": res.callback_id,
                                "callbacks": response
                            });
                        }
                        return done;
                    });
                });
            });
        });
    }
}

if (typeof(module) != "undefined") {
    module.exports = { Publisher };
}
