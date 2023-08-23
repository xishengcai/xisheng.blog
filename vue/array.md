

```vue.js
var Arry = ['Monday',' Tuesday','Sunday']; //Array

// using the toString() method
arrA = Arry.toString(); 

console.log(arrA); // 'Monday, Tuesday,Sunday'

// using the join() method 
arrB = Arry.join(',');

console.log(arr); // 'Monday, Tuesday,Sunday'

let arrC = '';
for (let i = 0; i < Arry.length; i++) {
    arrC += Arry[i];
    if (i !== Arry.length - 1) {
        arrC += ',';
    }
}
return str;

console.log(arrC);  // 'Monday,Tuesday,Sunday'
```





```js
const resp = await fetch('https://example.com', {
  method: 'POST',
  mode: 'cors',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify([1, 2, 3, 4, 5])
});
```

```js
const arr = JSON.parse("[1, 2, 3]")
// arr is an array
// [1, 2, 3]
```







https://sortoutcode.com/blog/how-to-convert-array-to-string-in-vuejs/



https://blog.boot.dev/javascript/converting-an-array-to-json-object-in-javascript/