
10-01	�������ƺ���䣨�����䣩
		QPen QBrush 
		QPainter�� drawArc drawRect drawEllipse drawPolygon fillRect
		eraseRect drawLine drawText setBrush setColorAt
		���Խ��� ���佥�� ׶�ν���
		QLinearGradient QRadialGradient QConicalGradient
10-02	����ϵͳ
		QPainter��save restore
		����ƽ�ƣ�translate
		������ת��rotate
10-03	����ϵͳ
		QPainter��setWindow �����߼��������ͽ���ߵȷָ���
		setMouseTracking(true) �����°���Ҳ�ܴ�������ƶ��¼�
10-04	����ϵͳ-ģ��ʱ����ת
		QPainter��setWorldTransform 
		QTransform��translate scale rotate
10-05	��������-�����ı�
		QPainter��drawText
		QFont��setUnderline setCapitalization setCapitalization
10-06	����·��
		QPainterPath������QML���canvas����moveTo lineTo  addEllipse
		cubicTo(���ױ�����) translate
10-07	����·��
		QPainterPath��setFillRule(����״�ཻ��ʾ����)
10-08	����ͼ��-�ֶ�������Ϊͼ��
		QImage QPixmap QBitmap QPicture
		QPainter��begin��ָ�������豸�� end
10-09	����ͼ��-��ʾ�ⲿͼ��-Image
		QPainter drawImage
		QImage load
		QTransform transform
10-10	����ͼ��-��ʾ�ⲿͼ��-Pixmap
		QPixmap��load 
		��ȡ����ͼƬ
10-11	����ģʽ
		QPainter��setCompositionMode(ͼ�����ӹ���)
10-12	˫�����ͼ