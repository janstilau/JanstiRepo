var a = {
    p: 'Hello',
    b: {
        name: 'bbbb',
      m: function() {
        console.log(this.name);
      }
    }
  };
  
  a.b.m() // undefined