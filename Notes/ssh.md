# SSH

SSH是每一台Linux电脑的标准配置。 用于远端登录.

当登录的时候, SSH 服务器会有一个警告信息, 然后将自己的公钥显示在终端上, 用户其实是需要自己到服务器的网站上查询显示的终端是不是网站上存储的终端信息. 之所以这样做是因为中间人可能伪造终端信息, 然后冒充服务器. 在 https 中可以通过证书的方式, 但是 ssh 里面没有证书, 所以这里是把决策权交给了用户.

当确定公钥是服务器的公钥之后, 就会将用户的用户密码用公钥加密, 然后将加密信息在网络上传输到服务器端, 服务器用私钥解密后得到原始信息. 因为是加密的信息, 所以不存在被获取的可能.

下一次登录的时候, 因为上一次公钥被用户认为有效, 就不会显示警告信息了, 而是直接登录.

用户可以生成自己机器的公钥私钥信息, 然后将公钥存放在服务器上. 那么用这种方式, 服务器在登录的时候, 会发送一个随机字符串过来, 用户用自己的私钥对这个随机字符串签名, 然后返回给服务器, 服务器再用用户的公钥解密, 发现解密后的就是自己发送的字符串, 就认定了用户是真实的用户. 用这种实现用户存储公钥在服务器的办法, 就省去了输入账号密码的过程了.