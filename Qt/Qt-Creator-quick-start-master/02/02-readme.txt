------------------------------------
.pro�ļ���Ҫ��
	greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

�����б���ָ�

        ��.ui�ļ�����ͷ�ļ���
	uic -o ui_hellodialog.h hellodialog.ui
        ���̱���������

	//����.pro�ļ�
	qmake -project

	qmake
	mingw32-make

------------------------------------

02-01	Qt Widgets Application
02-02	Empty qmake Project
02-03	main.cpp+�����б���
02-04	02-3 + .ui
02-05	�Զ���c++��