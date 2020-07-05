---
title: "Angular js"
date: 2020-7-4T10:21:07+08:00
draft: false
---

## what 
    AnjularJS extends HTML with new attributes.
    AnjularJS is perfect for single page applications(SPAs)
    
## terminology
- directive
- expression
- filter
- module
- controller

## directive
AnjularJS lets you extend HTML with new attributes called Directives.

AnjularJS has a set of built-in directives which offers functionality to your application.

AnjularJS also lets you define your own directives.

AngularJS directives are extended HTML attributes with the prefix ng-.

The ng-app directive initializes an AngularJS application.

The ng-init directive initializes application data.

The ng-model directive binds the value of HTML controls (input, select, textarea) to application data.

Read about all AngularJS directives in our AngularJS directive reference.

Common used directive
- ng-repeat
- ng-app
- ng-module
- ng-init
- ng-controller


### example
```javascript
<div ng-app="" ng-init="firstName='John'">

<p>Name: <input type="text" ng-model="firstName"></p>
<p>You wrote: {{ firstName }}</p>

</div>
```

## model
The ng-model directive binds the value of HTML controls(input, select, textarea) to application data.
```javascript
<div ng-app="myApp" ng-controller="myCtrl">
  Name: <input ng-model="name">
</div>

<script>
var app = angular.module('myApp', []);
app.controller('myCtrl', function($scope) {
  $scope.name = "John Doe";
});
</script>
```

two-way binding
```javascript
<div ng-app="myApp" ng-controller="myCtrl">
  Name: <input ng-model="name">
  <h1>You entered: {{name}}</h1>
</div>
```

## modules
The module is a container for the different parts of an application

The module is a container for the application controllers.

controllers always belong to  a module.

### create  a module
```angularjs
<div ng-app="myApp"> ...</div>
<script>
var app = angular.module("myApp", []);
</script>
```
### adding a controller
```angularjs
<div ng-app="myApp" ng-controller="myCtrl">
{{ firstName + " " + lastName }}
</div>

<script>

var app = angular.module("myApp", []);

app.controller("myCtrl", function($scope) {
  $scope.firstName = "John";
  $scope.lastName = "Doe";
});

</script>
```


## expression
AngularJS expressions are much like JavaScript expressions: They can contain literals, operators, and variables.

Example {{ 5 + 5 }} or {{ firstName + " " + lastName }}


## controller
AnjularJS controllers control the data of AnjularJS applications.</br>
AnjularJS controllers are regular JavaScript Objects.

example
```javascript
<div ng-app="myApp" ng-controller="myCtrl">

First Name: <input type="text" ng-model="firstName"><br>
Last Name: <input type="text" ng-model="lastName"><br>
<br>
Full Name: {{firstName + " " + lastName}}

</div>

<script>
var app = angular.module('myApp', []);
app.controller('myCtrl', function($scope) {
  $scope.firstName = "John";
  $scope.lastName = "Doe";
});
</script>
```

application explained:
This angularJS application is defined by ng-app="myApp". The application runs inside the <div>.

The ng-controller="myCtrl" attribute is an AngularJS directive. It defines a controller

The myCtrl function is a JavaScript function.


## scope
The scope is the binding part between the HTML(view) and the JavaScript(controller).

The scope is an object with the available properties and methods.

The scope is available for both the view and the controller.

If we consider an AnjularJS application to consist of:
- View, which is the HTML
- Model, which is the data available for the current view.
- Controller, which is the JavaScript function that makes/changes/removes/controls the data.

This scope is a JavaScript Object with properties and methods, which are available for both the view and the controller.

Example
```javascript
<div ng-app="myApp" ng-controller="myCtrl">

<input ng-model="name">

<h1>My name is {{name}}</h1>

</div>

<script>
var app = angular.module('myApp', []);

app.controller('myCtrl', function($scope) {
  $scope.name = "John Doe";
});
</script>
```
### Root Scope
All application have a $rootScope which is the scope created on the HTML element that contains the  ng-app directive.

THe rootScope is available in the entire application.

If a variable has the same name in both the current scope and  in the rootScope, the application uses the one in the current scope.

Example
```javascript
<body ng-app="myApp">

<p>The rootScope's favorite color:</p>
<h1>{{color}}</h1>

<div ng-controller="myCtrl">
  <p>The scope of the controller's favorite color:</p>
  <h1>{{color}}</h1>
</div>

<p>The rootScope's favorite color is still:</p>
<h1>{{color}}</h1>

<script>
var app = angular.module('myApp', []);
app.run(function($rootScope) {
  $rootScope.color = 'blue';
});
app.controller('myCtrl', function($scope) {
  $scope.color = "red";
});
</script>
</body>
```

## Filters
AngularJS provides filters to transform data:
- currency Format a number to a currency format.
- date Format a date to a specified format.
- filter Select a subset of items from an array.
- json Format an object to a JSON string.
- limitTo Limits an array/string, into a specified number of elements/characters.
- lowercase Format a string to lower case.
- number Format a number to a string.
- orderBy Orders an array by an expression.
- uppercase Format a string to upper case.

```javascript
<!DOCTYPE html>
<html>
<script src="https://ajax.googleapis.com/ajax/libs/angularjs/1.6.9/angular.min.js"></script>
<body>

<p>Click the table headers to change the sorting order:</p>

<div ng-app="myApp" ng-controller="namesCtrl">

<table border="1" width="100%">
<tr>
<th ng-click="orderByMe('name')">Name</th>
<th ng-click="orderByMe('country')">Country</th>
</tr>
<tr ng-repeat="x in names | orderBy:myOrderBy">
<td>{{x.name}}</td>
<td>{{x.country}}</td>
</tr>
</table>

</div>

<div ng-app="myApp" ng-controller="">
<table border="1" width="">

<script>
angular.module('myApp', []).controller('namesCtrl', function($scope) {
    $scope.names = [
        {name:'Jani',country:'Norway'},
        {name:'Carl',country:'Sweden'},
        {name:'Margareth',country:'England'},
        {name:'Hege',country:'Norway'},
        {name:'Joe',country:'Denmark'},
        {name:'Gustav',country:'Sweden'},
        {name:'Birgit',country:'Denmark'},
        {name:'Mary',country:'England'},
        {name:'Kai',country:'Norway'}
        ];
    $scope.orderByMe = function(x) {
        $scope.myOrderBy = x;
    }
});
</script>

</body>
</html>

```

## AngularJS Service
In AngularJS you can make your own service, or use one of the many built-in services.

In AngularJS, a service is a function, or object, that is available for, and limited to, your AngularJS application.

AngularJS has about 30 built-in services. One of them is the $location service.

The $location service has methods which return information about the location of the current web page:

Example:
```javascript
var app = angular.module('myApp', []);
app.controller('customersCtrl', function($scope, $location) {
    $scope.myUrl = $location.absUrl();
});
```

- timeout
- http.get().then()
- location
- interval

Example： create your own service
```javascript
app.service('hexafy', function() {
  this.myFunc = function (x) {
    return x.toString(16);
  }
});

app.filter('myFormat',['hexafy', function(hexafy) {
  return function(x) {
    return hexafy.myFunc(x);
  };
}]);
```

## Http
The AngularJS $http service makes a request to the server, and returns a response.

Example
```javascript
var app = angular.module('myApp', []);
app.controller('myCtrl', function($scope, $http) {
  $http({
    method : "GET",
      url : "welcome.htm"
  }).then(function mySuccess(response) {
    $scope.myWelcome = response.data;
  }, function myError(response) {
    $scope.myWelcome = response.statusText;
  });
});
</script>
```

methods:
- .delete()
- .get()
- .head()
- .jsonp()
- .patch()
- .post()
- .put()

Properties
The response from the server is an object with these properties:

- config the object used to generate the request.
- data a string, or an object, carrying the response from the server.
- headers a function to use to get header information.
- status a number defining the HTTP status.
- statusText a string defining the HTTP status.

```javascript
var app = angular.module('myApp', []);
app.controller('myCtrl', function($scope, $http) {
  $http.get("welcome.htm")
  .then(function(response) {
    $scope.content = response.data;
    $scope.statuscode = response.status;
    $scope.statustext = response.statusText;
  });
});
```

```javascript
<div ng-app="myApp" ng-controller="customersCtrl">

<ul>
  <li ng-repeat="x in myData">
    {{ x.Name + ', ' + x.Country }}
  </li>
</ul>

</div>

<script>
var app = angular.module('myApp', []);
app.controller('customersCtrl', function($scope, $http) {
  $http.get("customers.php").then(function(response) {
    $scope.myData = response.data.records;
  });
});
</script>
```
Application explained:

The application defines the customersCtrl controller, with a $scope and $http object.

$http is an XMLHttpRequest object for requesting external data.

$http.get() reads JSON data from https://www.w3schools.com/angular/customers.php.

On success, the controller creates a property, myData, in the scope, with JSON data from the server.

