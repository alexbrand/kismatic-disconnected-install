set -e
n=0
while true
do
	  ls scripts && break || true
	    n=$((n+1))
	      if [ $n -ge 3 ]; then exit 1; fi
	        echo "Retrying..."
		  sleep 5
	  done
