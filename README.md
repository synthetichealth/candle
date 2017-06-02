# Candle
FHIR microserver:
 - FHIR STU3 version 3.0.1
 - JSON support only

## Setup
Install the dependencies:
```
bundle install
```
Before running the app, setup a postgresql database server, version 9.5 or higher with a user `candle`. Create the database using the `resources\db.sql` script.

Then, start the server:
```
bundle exec ruby app.rb
```

Access the FHIR microservice at `http://localhost:4567/fhir`

## Endpoints

 - `http://localhost:4567/fhir/metadata`
 - `http://localhost:4567/fhir/Patient`
 - `http://localhost:4567/fhir/Observation`

### Supported Operations
Resource | Read | Write | Update | Delete | Search
---------|:----:|:-----:|:------:|:------:|-------
`Patient` | Y | Y | N | N | `name`, `gender`, `birthdate`, `race`, `ethnicity`, `address-city`, `_has`, `page`
`Observation` | Y | Y | N | N | `patient`, `encounter`, `code`, `date`, `value-quantity`, `page`


## License

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
```
http://www.apache.org/licenses/LICENSE-2.0
```
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
