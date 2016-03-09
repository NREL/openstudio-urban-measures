# OpenStudio Urban Modeling Web Application

## Local Development

Install ruby 2.2.2 using rbenv or your preferred method.  On Windows we use [RubyInstaller](http://rubyinstaller.org/downloads/).

Download and install [MongoDB](https://www.mongodb.org).  Open a command propmpt and go to the MongoDB bin directory (on Windows this is 'C:\Program Files\MongoDB\Server\3.0\bin').  Start Mongo with the following command 

```
mongod
```

Open a separate console, change directories to the '\openstudio-urban-measures\website\' directory and install the gem dependencies:

```
bundle install
```

then start the Rails server

```
rails s
```

View the app in your browser at http://localhost:3000

Open a separate console, change directories to the '\openstudio-urban-measures\website\' directory and initialize the database:

```
rake db:setup
```

then add default data:

```
rake testing:batch_upload_features
```

To reset the database at any time use:

```
rake db:reset
```

---coming soon---

## Deployment with Docker and Docker-Compose