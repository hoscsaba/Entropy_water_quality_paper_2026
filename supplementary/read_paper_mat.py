import struct,zlib,numpy as np,sys

def elem(buf,p):
 first=struct.unpack_from('<I',buf,p)[0]
 if first>>16:
  t=first&65535;n=first>>16;return t,buf[p+4:p+4+n],p+8
 t,n=struct.unpack_from('<II',buf,p)
 data=buf[p+8:p+8+n];return t,data,p+8+((n+7)//8)*8

def matrix(data,interest=None):
 p=0;fl,pay,p=elem(data,p);klass=struct.unpack_from('<I',pay)[0]&255
 dim,pay,p=elem(data,p);dims=struct.unpack('<'+'i'*(len(pay)//4),pay)
 nam,pay,p=elem(data,p);name=pay.decode(errors='replace')
 if klass==2:
  t,pay,p=elem(data,p);width=struct.unpack_from('<I',pay)[0]
  t,pay,p=elem(data,p);fields=[pay[i:i+width].split(b'\0')[0].decode() for i in range(0,len(pay),width)]
  if interest=='list':return name,fields
  if interest in fields:
   for f in fields:
    t,pay,p=elem(data,p)
    if f==interest:
     return matrix(pay)
  return name,{'class':klass,'fields':fields}
 if klass==6:
  t,pay,p=elem(data,p)
  dt={9:'<f8',7:'<f4',5:'<i4',6:'<u4',1:'i1',2:'u1'}.get(t)
  if dt:return name,np.frombuffer(pay,dtype=dt).copy().reshape(dims,order='F')
 return name,{'class':klass,'dims':dims}

def read(path,interest='design_diameters'):
 b=open(path,'rb').read();p=128
 while p<len(b)-8:
  t,n=struct.unpack_from('<II',b,p);blob=b[p+8:p+8+n]
  if t==15:
   inner=zlib.decompress(blob);t,pay,_=elem(inner,0)
   if t==14:
    x=matrix(pay,interest)
    if interest=='list':print(path,x)
    elif not isinstance(x[1],dict):return x[1]
   p+=8+n
  elif t==14:
   x=matrix(blob,interest)
   if interest=='list':print(path,x)
   elif not isinstance(x[1],dict):return x[1]
   p+=8+((n+7)//8)*8
  else:break
 if interest=='list':return
 raise KeyError(interest)
if __name__=='__main__':
 for path in sys.argv[1:]:
  read(path,'list');x=read(path);print('diameters',x.shape,x.ravel()[:10],x.min(),x.max())
