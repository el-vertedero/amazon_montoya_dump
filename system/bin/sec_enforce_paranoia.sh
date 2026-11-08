# Copyright (C) 2014 Amazon Technologies, Inc. All Rights Reserved
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

TAG="paranoia: "

mlog() {
    echo $TAG $@ > /dev/kmsg
}

perm_f() {
    chmod 400 /d/$1
}

perm_d() {
    chmod 700 /d/$1
}
mlog "enforce"

#Mod perms for top level files
perm_f apanic
perm_f gpio
perm_f pmem
perm_f sched_features
perm_f wakeup_sources

# Mod perms for all folders except "tracing"
perm_d bdi
perm_d binder
perm_d bsc-i2c0
perm_d bsc-i2c1
perm_d bsc-i2c2
perm_d bsc-i2c3
perm_d dtsdump
perm_d extfrag
perm_d hid
perm_d ieee80211
perm_d kona_cpufreq
perm_d memblock
perm_d mmc0
perm_d profiler
perm_d rcu
perm_d usb

mlog "done"
