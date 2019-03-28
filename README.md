# 🗜🌄 ImageMin

<p align="center">
  <img height=400 title="Make Images Great Again!" src ="./img/hero.gif" />
</p>

> Simple, standalone, cache-less, configurable, secure service to optimise vendor images on the fly.

Based on: [image_optim](https://github.com/toy/image_optim) ruby gem binded with OpenSSL ciphering and roda **/** puma goodness.

## Why

Sometimes you get third party images from APIs, user inputs, etc. Often those images could be hosted behind HTTP server (which could be the issue if your site is HTTPS), anyone can see where the image loaded from and, moreover, Google PageSpeed Tools could complain about their (images) sizes and compression possibility.

This service solves all these issues: host it on your subdomain `https://images.example.com` behing HTTPS, encrypt original images sources, compress images on the fly (add some caching in front of it to taste).

## How

**🌄 Take original URL** → **🔐 Encrypt it with symmetric AES-256** → **📩 Send the digest to the ImageMin** → **📦 Get compressed image** → **💵 PROFIT!!!!11**

## Configuration

Service uses [dotenv](https://github.com/bkeepers/dotenv) gem to configure all the key params:

```sh
PLACEHOLDER_IMAGE=./img/placeholder.jpeg       # <<< Default image placeholder relative path
IMAGE_OPTIM_CONFIG_PATH=./image_optim.yml      # <<< Optimisation Workers config file relative path
SECRET_KEY=foobarfoobarfoobarfoobarfoobarfo    # <<< Secret key to encrypt URLs with (32B)
PUBLIC_IV=foobarfoobarfoob                     # <<< No so secret IV (keep static to have symmetric ciphering, 16B)
SECRET_TOKEN=alicebobalicebobalicebobalice     # <<< Secret token to access URL generation endpoint (see `Dev` section)
MEMOISATION_LIMIT=10000                        # <<< Memoisation rotation limit (play with it to save memory)
CLIENT_CACHE_TTL=4                             # <<< For how long a browser should cache the image (hours)
HOST=localhost                                 # <<< Host to generate liks using secret URL
PORT=9292                                      # <<< Port to generate liks using secret URL
SITE=localhost:9292                            # <<< Host + port to for a URL on `/secret`
RACK_ENV=development                           # <<< App environment (in prod should be `production`)
RETRIEVAL_TIMEOUT=10                           # <<< Max time we let for a 3rd party image to get retrived (seconds)
COMPRESSION_TIMEOUT=5                          # <<< Max time we let for a 3rd party image to get compressed (seconds)
MAX_THREADS=16                                 # <<< Puma/Heroku threads configuration
WEB_CONCURRENCY=5                              # <<< Puma/Heroku workers configuration
ZOMBIES_KILLING_RATE=1                         # <<< What % of requests triggers zombie processes killing
ZOMBIES_MAX_POPULATION=50                      # <<< Zombies population threshold before cleaning
VALIDATE_ONLINE=true                           # <<< Turn online validation on and off
LOG_LEVEL=WARN                                 # <<< App log level DEBUG < INFO < WARN < ERROR < FATAL < UNKNOWN
```

Apart from this config you could and probably should tweak particular optimisation workers used. For all the details check out the original gem's [`Configuration`](https://github.com/toy/image_optim#configuration) section or open heavily commented `image_optim.yml` in the project's `/config` directory.

You have to set your own `Rack::Attack` and `ImageOptim` configurations anyway. Luckily it's as easy as copying & renaming sample files in the `/config` directoiry. You could leave defaults or set your preferable settings.

⚠️ **WARNING**: Config files in the `/config` directory are required but not tracked with git, so before starting it locally, setting it up on staging/production or building Docker images you should create your own config files from samples provided!!!

## Samples

On **default** settings image_optim gives ~ this results for sample images:

| Before | After |
------------ | -------------
<img height=200 title="Before" src ="./img/samples/sample_1_before.jpg" /> | <img height=200 title="After" src ="./img/samples/sample_1_after.jpg" />
JPEG image | JPEG image
151 KB (151,498 bytes) | 138 KB (138,394 bytes)
1500 × 970 pixels | 1500 × 970 pixels
72 pixels/inch | 72 pixels/inch
RGB | RGB
— | - 8.65%

| Before | After |
------------ | -------------
<img height=222 title="Before" src ="./img/samples/sample_2_before.gif" /> | <img height=222 title="After" src ="./img/samples/sample_2_after.gif" />
Graphics Interchange Format (GIF) | Graphics Interchange Format (GIF)
465 KB (465,381 bytes) | 464 KB (464,289 bytes)
500 × 359 pixels | 500 × 359 pixels
sRGB IEC61966-2.1 + ⍺-channel | sRGB IEC61966-2.1 + ⍺-channel
— | - 0.23%

## REST API

| Endpoint | Params | Result
------------ | ------------- | -------------
**GET** `/:encrypted_url` | | **200**: Compressed binary image
**GET** `/<wrong_url>` | | **200**: Default placeholder image
**GET** `/` | | **404**: No web page was found for the web address
**GET** `/status` | | **200**: Service heartbeat
**POST** `/secret` | Form URL-Encoded:<br/><span style="padding-left: 25px">**image_uri**: original image URL</span><br/><span style="padding-left: 25px">**secret_token**: secret access token</span> | **200**: HTML `<a>` tag with encrypted image link</br>**400**: if any param is absent or the secret token is wrong

## Dev

* To get the service up and running just execute:

```sh
./bin/setup
foreman start

# or

foreman start -e ./.env.test # for testing
```

* To build docker image:

```sh
./bin/setup
docker image build -t image_min . --no-cache
```

* To build & run docker container (while coding):

```sh
docker image build -t image_min . && docker container run -it -e 'PORT=9292' -e 'RACK_ENV=DEVELOPMENT' -p 9292:9292 --name image_min --rm image_min
```

* To run docker container:

```sh
docker container run -it -e 'PORT=9292' -e 'RACK_ENV=DEVELOPMENT' -p 9292:9292 --name image_min --rm image_min

# or

docker container run -it -e 'PORT=9292' -e 'RACK_ENV=TEST' -p 9292:9292 --name image_min --rm image_min # for testing
```

* Heroku usage and deployment:

```sh
heroku git:remote -r productrion -a image-min-productrion # add remote app (name could differ)
heroku plugins:install heroku-container-registry          # install Docker registry plugin
heroku registry:login                                     # login to Heroku Docker images registry
heroku container:push web                                 # deploy builded image to the registry and run a container
heroku logs -t                                            # tail app's logs
heroku config:set SITE=image-min.herokuapp.com            # configure ENV vars (SITE here used is for example puroses only)
```

* As for a developer there's not much to mess around with. But in case of developemnt-mode manual testing you may want to generate sample URL's. For this exact purpose the service provides a dedicated endpoint `/secret`. Send there a `Form URL-Encoded` POST request:

```sh
## Secret Duplicate
curl -X "POST" "http://localhost:9292/secret" \
     -H 'Content-Type: application/x-www-form-urlencoded; charset=utf-8' \
     --data-urlencode "secret_token=alicebobalicebobalicebobalice" \
     --data-urlencode "image_uri=https://images-na.ssl-images-amazon.com/images/I/81IQp9uUdRL._SL1500_.jpg"
```

> **PRO TIP**: in case you use Postman, set this values using `Bulk Edit` mode

```
image_uri: https://images-na.ssl-images-amazon.com/images/I/81IQp9uUdRL._SL1500_.jpg
secret_token: alicebobalicebobalicebobalice
```

If you've done everything properly you would receive a link for `localhost:9292` (`$SITE`) like `http://localhost:9292/<ciphered_vendor_url>`

* To see a placeholder image — just spoil this original link by, for example, removing one symbol at the end of the URL.

> **PRO TIP**: to see the `PROFIT!!!!11™` you may be interested in using something like Google Chrome's [`View Image Info`](https://chrome.google.com/webstore/detail/view-image-info-propertie/jldjjifbpipdmligefcogandjojpdagn) plugin.

* To generate and open YARD documentation you could execute something like: `yard && open doc/index.html` or `./bin/docs` to preserve images.

* If you care about hight quality testing and ever asked yourself who would test the tests (after all they are also code and qiute a lot of it!) then probably, you'd like to run mutation testing:

```
# For exmaple:
mutant -j 1 --fail-fast -I ./lib/image_compressor.rb -r ./spec/image_compressor_spec.rb --use rspec 'ImageCompressor'
```

> **PRO TIP**: keep in mind that often there are false-negative cases called `Equivalent Mutants`. Don't waste your time trying to fix them in the code or on the tests side.
>
> Also it's recommended to test network and concurrent things that might meddle with the results/ports using just one job i.e. `-j 1`, but also remember that it's time consuming process!

## Testing

In the simplest case you can run tests using:

```sh
RACK_ENV=test rspec # run tests using .env.local.test
```

In this case it'll automatically run its own server on `http://localhost:9292` and test REST API against this built-in server.

If you've got an error and the test log says that server logs could contain some details, you'd need to run tests against a real server and check the logs yourself:

```sh
# Run this in one terminal window/tab (or tmux pane)
foreman start -e ./.env.local.test

# Run this in another terminal window/tab
RACK_ENV=test rspec
```

Last option is to run tests against interactive (running in foreground) Docker container:

```sh
docker image build -t image_min . && docker container run -it -e 'PORT=9292' -e 'RACK_ENV=test' -p 9292:9292 --name image_min --rm image_min
```

> ⚠️ Caveats: sometimes delays testing depends on your machine's workload therefore some tests could fail with `execution expired` message. In this case — just restart the tests.

> ℹ️ Dev note: in case we need to test our own related gem the easiest way is to add it as a local dependency in Gemfile: `gem 'network_utils', path: './network_utils'`and `ADD ./network_utils /app/network_utils` in Dockerfile

## Heroku support

The service could be easily deployed on Heroku using [Container Registry](https://devcenter.heroku.com/articles/container-registry-and-runtime):

```sh
heroku container:login
heroku container:push web -r production # if you have already existed app
```

In order to ba able to execute additioanl commands in the containers you should enable this feature on Heroku:

```sh
heroku buildpacks:add https://github.com/heroku/exec-buildpack -r production
heroku features:enable runtime-heroku-exec -r production

heroku ps:exec -r production --dyno=web.1 # to get to the dyno.1's shell
```

All the files needed for this feature to work, already build into the project (see: `./.profile.d/`)

## Known Issues

* [ImgeOptim gem](https://github.com/toy/image_optim) produces children processes (binary compressors) and since the lib itself at the moment has no compression timeouts we have to set our own timeouts from the outside. Therefore, when interrupting the execution of the compression method, we produce ZN-stat marked processes (zombies) each of which consumes 1 thread, which could become an issue on serivices like Heroku where we have limited thread pool ([512 available on Heroku for standard-2x Dynos](https://devcenter.heroku.com/articles/limits#processes-threads)). While the [issue](https://github.com/toy/image_optim/pull/149) is being solved with the PR on the official repository we're doing our best to avoid full thread-pool consuming:
	- Implementing a middleware which, using system calls, detects/counts and kills zombie parent workers (with SIGTERM - 15) for a fraction (about 1%) of requests and consequently lets Puma master process to restart killed cluster members (for configuration see `ZOMBIES_KILLING_RATE`, `ZOMBIES_MAX_POPULATION` environment variables)

* Often REST specs fail due to the execution timeouts. If it occures again and again on your local machine, try to execute test suite against the Docker version of the app. **BTW**: running tests with Docker you ain't gonna get 100% coverage, cause the line where the test server gets started won't be executed.

## ToDo / Features

- [x] Optimise vendor images on the fly and transparently serve the compressed versions
- [x] Resolve symmetrically ciphered URLs (for cross-project usage with the same keys/ivs) into original image URLs
- [x] Dev endpoint to generate URLs with the given key/iv settings
- [x] Heartbeat / Status endpoint to minitor service availability
- [x] Provide ENV configuration options and Optimisation Workers config file
- [x] Memoisation to save on cipher/decipher process for processed URLs
- [x] Procfile to make it Heroku / Foreman flavoured
- [x] Docker images building environment
- [x] Rack::Attack with a separate configuration to limit requests if needed
- [x] Setup script for initial environment configuration (bin/setup)
- [x] Full test coverage
- [ ] Maximum mutation test coverage
