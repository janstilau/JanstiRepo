
07-01	����ģ��--�źźͲۣ�MyDialog�����źŵ�Widget�Ĳ�
	�ź�signals����slots������connect�������ź�emit
07-02	����ģ��--�źźͲ۵��Զ��������Ͽ�����
	QPushButton��myButton
	�Զ���ۣ�on_myButton_clicked()
07-03	����ģ��--����ϵͳ��Q_PROPERTY
	ע������userName��ʵ��READ��������ʵ��WRITEд����������NOTIFY֪ͨ��Ϣ
    	Q_PROPERTY(QString userName READ getUserName 
	WRITE setUserName NOTIFY userNameChanged)
07-04	����ģ��--��������ӵ��Ȩ
	children()
	�����Ӳ���ָ���������������Ӳ�����ָ��������
07-05	������--˳������
	QList: replace append prepend takeAt size at contains count indexOf
07-06	������--map����
	һ����ֵ
	QMap value insert  insertMulti
	QMultiMap insert values
07-07	������--List��������Java����������
	ֻ��������������List����
	QListIterator : hasNext next hasPrevious previous
	��д������������List����
	QMutableListIterator : hasPrevious previous remove  setValue toFront  hasNext next
07-08	������--map��������Java����������
	QMapIterator��QMutableMapIterator
07-09	�����ࣨSTL����������
	QMapIterator��QMutableMapIterator
07-10	foreach�ؼ���--��������˳�����
	foreach(QString str, list){		//��list�л�ȡÿһ��
		qDebug() << str;		//���ΪA,B,C
	}
07-11	������--ͨ���㷨
	algorithm
	�㷨��copy/equal/fill/count/lower_bound/sort/stable_sort/greater/swap
07-12	������--QString
	�༭������append replace  insert trimmed  simplified split isNull isEmpty
	��ѯ������right left mid number toFloat toUpper toLower arg ��qPrintable
07-13	QVariant��toInt toFloat toString type value canConvert convert 
07-14	������ʽ
	QRegExp��setPattern indexIn setPattern replace setPatternSyntax exactMatch
	cap�����ص�n���ӱ��ʽ������ı�������ƥ�����������0����Բ���ŵ��ӱ��ʽ��
	�д�1��ʼ��������������δ�����Բ���ţ���
	setCaseSensitivity